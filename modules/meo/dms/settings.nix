# DMS-Einstellungen: EINMALIGE ERSTBEFUELLUNG, danach gehoert die Datei DMS.
#
# MODIFIED 2026-09-01. Vorher setzte diese Datei die Modul-Option
# programs.dank-material-shell.settings. Das war ein Fehler mit Folgen:
#
#   Das DMS-Modul schreibt diese Option per `xdg.configFile … source = …`.
#   `source` heisst in home-manager IMMER Symlink in den Nix-Store, und der
#   Store gehoert root und ist schreibgeschuetzt. Sobald EIN Schluessel
#   gesetzt war, wurde die GANZE Datei unveraenderlich — und settings.json
#   kennt 353 Schluessel. Elf davon kamen aus Nix (plus sechs aus dem
#   Stylix-Ziel), die uebrigen 342 fielen bei jedem Start auf DMS'
#   Werkseinstellung zurueck. In der Oberflaeche vorgenommene Aenderungen
#   lebten nur im Arbeitsspeicher und waren nach jedem Neustart weg.
#   Dasselbe galt fuer ~/.local/state/DankMaterialShell/session.json, das
#   ueber programs.dank-material-shell.session am Stylix-Ziel hing
#   (Hell/Dunkel-Modus, Nachtmodus, angeheftete Programme, Wetterort …).
#
# Bei einer Datei, die die Anwendung selbst schreibt, ist die Frage nicht
# „setzt Nix den richtigen Wert", sondern WEM DIE DATEI GEHOERT. Genau eine
# Partei kann sie besitzen. Hier ist es DMS; Nix legt sie nur an, wenn sie
# fehlt, und fasst sie danach nie wieder an.
#
# Konsequenz, bewusst in Kauf genommen: Der Ist-Zustand der Oberflaeche
# steht nicht mehr im Repo und wandert nicht automatisch auf meo-work.
# Reproduzierbar bleibt der ERSTE Start — die sicherheits- und
# hardwarerelevanten Werte unten.
{
  config,
  lib,
  pkgs,
  host,
  ...
}: let
  vars = import ../../../hosts/${host}/variables.nix;

  # Werte, die beim ersten Start stimmen MUESSEN. Sie gewinnen auch dann,
  # wenn eine aeltere Konfiguration uebernommen wird (siehe Aktivierung).
  overrides = {
    # Sperre nach 10 Minuten Untaetigkeit, wie zuvor unter Noctalia.
    # DMS' Werkseinstellung ist 0 = NIE sperren.
    acLockTimeout = 600;
    batteryLockTimeout = 600;

    # Bildschirm-Abschaltung. Auf meo AUS gegen den eDP-OLED-Freeze.
    fadeToDpmsEnabled = vars.dmsScreenOff or false;
    fadeToDpmsGracePeriod = 5;

    # DMS' Dock ist per Default AUS; Noctalia hatte eines.
    showDock = true;

    # Schriften aus Stylix, damit DMS beim ersten Start zum Rest des Systems
    # passt. Bewusst NICHT die frueher hier gesetzte Nerd-Font als
    # UI-Schrift: DMS ist Quickshell, also Qt, und Qt-Schriftmetriken waren
    # in dieser Konfiguration schon einmal die Ursache abgeschnittener
    # Popups (siehe qt-apps-need-rejectfont-not-substitution).
    fontFamily = config.stylix.fonts.sansSerif.name;
    monoFontFamily = config.stylix.fonts.monospace.name;
  };

  overrideFile = (pkgs.formats.json {}).generate "dms-settings-overrides.json" overrides;

  # Wallpaper fuer die Erstbefuellung. Bevorzugt die Datei im Repo statt des
  # Store-Pfads: der Store-Pfad ueberlebt keine Garbage Collection, das Repo
  # schon, und DMS soll das Bild spaeter selbst wechseln koennen.
  repoWallpaper = "${config.home.homeDirectory}/nixos-config/wallpapers/${baseNameOf vars.stylixImage}";
  storeWallpaper = "${config.stylix.image}";

  jq = lib.getExe pkgs.jq;
in {
  # Das Stylix-Ziel schreibt in dieselbe Option und wuerde die Datei erneut
  # zum Store-Symlink machen. DMS faerbt sich stattdessen selbst aus dem
  # Wallpaper (matugen, currentThemeName = "dynamic") — aus demselben Bild,
  # aus dem Stylix seine base16-Palette zieht, die Ergebnisse liegen also
  # nah beieinander.
  stylix.targets.dank-material-shell.enable = false;

  home.activation.dmsSeedConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if [[ -v DRY_RUN ]]; then
      echo "Wuerde DMS-Konfiguration erstbefuellen, falls sie fehlt"
    else
      dmsSeed() {
        local target="$1" json="$2"
        local base="$target.backup"

        # Echte Datei vorhanden -> sie gehoert DMS. Nicht anfassen.
        if [[ -f "$target" && ! -L "$target" ]]; then
          return 0
        fi

        # Ein Symlink kann nur ein Ueberbleibsel einer frueheren Generation
        # sein, in der Nix die Datei noch geschrieben hat.
        [[ -L "$target" ]] && rm -f "$target"
        mkdir -p "$(dirname "$target")"

        # Als Grundlage die von home-manager beiseitegeschobene aeltere
        # Konfiguration nehmen, sofern sie existiert UND gueltiges JSON ist.
        if [[ -f "$base" ]] && ${jq} -e . "$base" >/dev/null 2>&1; then
          ${jq} --argjson ov "$json" '. * $ov' "$base" > "$target"
          echo "DMS: $target aus $base uebernommen"
        else
          printf '%s\n' "$json" > "$target"
          echo "DMS: $target neu angelegt"
        fi
      }

      # ---- settings.json ----
      dmsSeed "$HOME/.config/DankMaterialShell/settings.json" "$(cat ${overrideFile})"

      # ---- session.json ----
      wp="${repoWallpaper}"
      [[ -f "$wp" ]] || wp="${storeWallpaper}"
      dmsSeed "$HOME/.local/state/DankMaterialShell/session.json" \
        "$(${jq} -n --arg wp "$wp" '{wallpaperPath:$wp, wallpaperPathDark:$wp, wallpaperPathLight:$wp}')"
    fi
  '';
}
