{pkgs, ...}:
# Dock-abhaengige GPU-Wahl fuer niri auf Host meo (Intel Arc iGPU + NVIDIA RTX 4080).
#
# Gleiche Ausgangslage wie bei modules/meo/hyprland-gpu-smart.nix: externe
# Monitore haengen an der NVIDIA-dGPU. Rendert der Compositor auf der iGPU, wird
# jeder Frame ueber PCIe kopiert -> Cursor-Lag. Im mobilen Betrieb soll die dGPU
# dagegen nach D3cold fallen duerfen.
#
# Unterschied zu Hyprland: niri kennt kein AQ_DRM_DEVICES. Die Renderer-Wahl
# sitzt in der Config unter debug { render-drm-device "..." }. Stattdessen: die
# HM-Config kopieren, den passenden debug-Block anhaengen und niri per
# NIRI_CONFIG auf die Kopie zeigen lassen.
#
# KORREKTUR 2026-08-31 (Fix-Runde 1 zu Aufgabe 8): hier stand bis eben "niri
# kennt KEIN include in KDL, verifiziert" -- das war falsch. Mit niri 26.04
# funktioniert `include` in KDL, wie die DMS-Integration (modules/meo/dms/
# niri.nix) beweist. Der Irrtum stammte aus der niri-Migration am 27.08. und
# ist genau deshalb gefaehrlich geblieben: niri loest RELATIVE include-Pfade
# gegen das VERZEICHNIS DER EINSCHLIESSENDEN DATEI auf, nicht gegen
# ~/.config/niri/. Die Kopie mit dem angehaengten debug-Block muss deshalb
# NEBEN der Basis liegen (also in ~/.config/niri/ selbst) -- sonst gehen die
# eigenen includes (hm.kdl, dms/*.kdl) ins Leere. niri validiert eine solche
# Kopie trotzdem klaglos: fehlende optional=true-includes sind nur eine
# Warnung, kein Fehler, und `niri validate` liefert Exit 0. Betraf nur `meo`
# (niri-smart), nicht `meo-work` (kein Wrapper, startet direkt auf
# ~/.config/niri/config.kdl).
#
# WICHTIG: In modules/meo/niri/ darf deshalb KEIN debug-Block stehen, sonst
# entsteht er hier doppelt.
#
# ---------------------------------------------------------------------------
# WARUM JEDER PFAD IN `exec niri-session` ENDET — NICHT IN `exec niri --session`
# ---------------------------------------------------------------------------
# Das niri-Package liefert share/systemd/user/niri.service mit:
#     BindsTo=graphical-session.target
#     Before=graphical-session.target
# Erst das STARTEN dieser Unit zieht graphical-session.target hoch (BindsTo
# impliziert Requires). `niri --session` startet ueberhaupt keine Unit — das
# Target bliebe inaktiv und JEDE User-Unit mit
# `WantedBy=graphical-session.target` waere tot: Noctalia (Bar, Dock, Launcher,
# Control-Center, Clipboard, Notifications, Wallpaper UND Lockscreen), udiskie,
# edp-refresh-switcher, bt-audio-monitor, vol-smart-watch. Mod+Alt+L wuerde die
# Maschine dann UNGESPERRT suspendieren.
#
# `niri-session` (gleiches Package) macht genau die richtige Reihenfolge:
# `systemctl --user import-environment` -> `systemctl --user --wait start
# niri.service` -> beim Ende `niri-shutdown.target`.
#
# Folge fuer die generierte Config: die Unit ruft `niri --session` ohne
# Argumente auf, ein `-c` kaeme also nie an. Stattdessen NIRI_CONFIG (siehe
# `niri --help`: "This can also be set with the `NIRI_CONFIG` environment
# variable"). Das bare `systemctl --user import-environment` in niri-session
# importiert die KOMPLETTE Umgebung in den User-Manager, also erbt niri.service
# unser NIRI_CONFIG.
#
# Das Schwestermodul modules/meo/hyprland-gpu-smart.nix DARF `exec Hyprland`
# direkt machen: Hyprland aktiviert sein Session-Target aus der eigenen Config
# heraus. Hier waere dieselbe "Vereinfachung" ein stiller Desktop-Totalausfall.
let
  nvidiaPci = "0000:01:00.0";
  intelPci = "0000:00:02.0";

  # Ermittelt render_node und mode aus den PCI-Adressen. Wird von niri-smart
  # (beim Login) UND von niri-reload (im Betrieb) gebraucht — deshalb hier
  # einmal definiert, statt in zwei Skripten auseinanderzudriften.
  gpuDecision = ''
      resolve_render_node() {
        local pci="$1" node
        node=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'renderD*' -printf '%f\n' 2>/dev/null | head -n1) || true
        if [ -n "''${node:-}" ] && [ -e "/dev/dri/$node" ]; then
          printf '%s\n' "/dev/dri/$node"
        fi
      }

      resolve_card() {
        local pci="$1" card
        card=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'card*' -printf '%f\n' 2>/dev/null | head -n1) || true
        printf '%s\n' "''${card:-}"
      }

      nvidia_node=$(resolve_render_node "${nvidiaPci}")
      intel_node=$(resolve_render_node "${intelPci}")
      nvidia_card=$(resolve_card "${nvidiaPci}")

      external_connected=0
      if [ -n "$nvidia_card" ]; then
        for status in /sys/class/drm/"$nvidia_card"-*/status; do
          [ -e "$status" ] || continue
          name=$(basename "$(dirname "$status")")
          case "$name" in
            *eDP*) continue ;;
          esac
          if [ "$(cat "$status")" = "connected" ]; then
            external_connected=1
            break
          fi
        done
      fi

      if [ "$external_connected" = "1" ] && [ -n "$nvidia_node" ]; then
        render_node="$nvidia_node"
        mode="docked: NVIDIA als Renderer"
      elif [ -n "$intel_node" ]; then
        render_node="$intel_node"
        mode="mobil: Intel, NVIDIA darf schlafen"
      else
        render_node=""
        mode="fallback: keine GPU-Bindung (Nodes nicht aufloesbar)"
      fi

  '';

  niriSmart = pkgs.writeShellApplication {
    name = "niri-smart";
    runtimeInputs = with pkgs; [coreutils findutils gnugrep niri];
    text = ''
      # Kein eigenes `set` noetig: writeShellApplication setzt bereits
      # `set -o errexit -o nounset -o pipefail`.

      ${gpuDecision}

      printf '[niri-smart] %s -- render-drm-device=%s\n' "$mode" "''${render_node:-unset}" >&2

      # Dieses stderr landet bei SDDM im Nichts: die Session wird ueber
      # sddm-helper gestartet, dessen Ausgabe nirgends aufgezeichnet wird.
      # Nach dem Login ist damit NICHT mehr feststellbar, welchen Modus der
      # Wrapper gewaehlt hat -- genau die Frage, die am 2026-08-28 offen blieb,
      # als der debug-Block in der Runtime-Config fehlte. Deshalb zusaetzlich
      # eine Statuszeile neben die generierte Config. Bewusst mit "|| true":
      # unter errexit duerfte ein volles tmpfs den Login nicht verhindern.
      status_file="''${XDG_RUNTIME_DIR:-/tmp}/niri-smart.status"
      printf '%s\nmode=%s\nrender_node=%s\n' \
        "$(date -Is 2>/dev/null || echo unbekannt)" \
        "$mode" "''${render_node:-unset}" > "$status_file" 2>/dev/null || true

      base="$HOME/.config/niri/config.kdl"
      # NEBEN der Basis, nicht in $XDG_RUNTIME_DIR: niri loest relative
      # include-Pfade (hm.kdl, dms/*.kdl) gegen das Verzeichnis DIESER Datei
      # auf. Lag die Kopie in /run/user/*, gingen die includes ins Leere --
      # siehe Kopfkommentar. Versteckte Datei, damit sie nicht wie eine
      # zweite echte Config aussieht.
      generated="$HOME/.config/niri/.niri-smart.kdl"

      # Ohne NIRI_CONFIG sucht niri selbst unter genau diesem Pfad. Fehlt die
      # Datei, faengt niris eigener Default das ab. Existiert sie aber nur mit
      # falschen Rechten, laeuft niri hier in denselben Lesefehler --
      # dieser Fallback rettet also nur den "fehlt"-Fall, nicht den "kaputt"-Fall.
      if [ ! -r "$base" ]; then
        printf '[niri-smart] %s nicht lesbar, ueberlasse Config-Suche niri selbst\n' "$base" >&2
        exec niri-session "$@"
      fi

      # NICHT `cp`. Die Quelle ist ein Symlink in den Nix-Store, und dort ist
      # alles 444. `cp` uebernimmt beim NEU ANLEGEN die Rechte der Quelle --
      # die Kopie waere also schreibgeschuetzt, und das Anhaengen des
      # debug-Blocks unten scheiterte an der eigenen Datei. Die Absicherung
      # dort faengt das zwar ab, aber sie startet dann OHNE GPU-Bindung, und
      # zwar still: die Meldung geht nach stderr, das SDDM verwirft. Genau
      # dieser Fehler kostete am 2026-08-28 einen Abend Fehlersuche.
      # `install -m` setzt die Rechte explizit und ist gegen die Store-Rechte
      # der Quelle immun.
      if ! install -m 0644 "$base" "$generated"; then
        printf '[niri-smart] Kopie von %s nach %s fehlgeschlagen, starte mit HM-Config\n' "$base" "$generated" >&2
        exec niri-session "$@"
      fi

      # Sinnvolleres Kriterium als der fruehere Groessenvergleich weiter unten
      # (der mit Aufgabe 8 entfallen ist, siehe dort): die Kopie muss
      # BYTE-IDENTISCH mit der Basis sein, direkt nach dem Kopieren und vor
      # jeder Veraenderung durch das Anhaengen. install meldet einen
      # Schreibfehler zwar per Exit-Code, aber cmp faengt zusaetzlich einen
      # stillen Partial-Write ab (z.B. ein tmpfs, das mittendrin volllaeuft,
      # ohne dass install das sauber propagiert).
      if ! cmp -s "$base" "$generated"; then
        printf '[niri-smart] Kopie von %s weicht von der Basis ab, starte mit HM-Config\n' "$base" >&2
        exec niri-session "$@"
      fi

      # Das Anhaengen ist bewusst abgesichert: unter errexit wuerde ein
      # Schreibfehler (praktisch nur ENOSPC auf dem tmpfs) das Script sonst
      # VOR jedem exec beenden und den Benutzer zurueck in den Greeter werfen.
      # So endet wirklich jeder Pfad in einem exec.
      if [ -n "$render_node" ]; then
        if ! {
          printf '\n// von niri-smart ergaenzt (%s)\n' "$mode"
          printf 'debug {\n    render-drm-device "%s"\n}\n' "$render_node"
        } >> "$generated"; then
          printf '[niri-smart] debug-Block liess sich nicht anhaengen, starte mit HM-Config\n' >&2
          exec niri-session "$@"
        fi
      fi

      # ENTFALLEN 2026-08-31 (Fix-Runde 1 zu Aufgabe 8): hier stand ein
      # Groessenvergleich "Kopie muss >= Basis sein", der genau den Fehlerfall
      # abfangen sollte, den dieser gesamte Fix behebt (Kopie besteht nur noch
      # aus dem angehaengten debug-Block). Seit Aufgabe 8 ist die Basis
      # (~/.config/niri/config.kdl) selbst nur noch ein 8-zeiliger
      # include-Stub (~310 Byte, siehe modules/meo/dms/niri.nix) statt der
      # vollen gerenderten Config. Jede Kopie plus debug-Block liegt WEIT
      # darueber -- der Vergleich haette also nie wieder ausgeloest, selbst
      # bei einer komplett leeren oder kaputten Kopie. Ersetzt durch den
      # cmp-Vergleich weiter oben: der prueft Byte-Identitaet mit der Basis
      # direkt nach dem Kopieren, bevor ueberhaupt etwas angehaengt wird --
      # unabhaengig davon, wie gross die Basis gerade ist.

      # Bricht lieber hier ab als in einer schwarzen Session.
      if ! niri validate --config "$generated"; then
        printf '[niri-smart] generierte Config ungueltig, starte mit HM-Config\n' >&2
        exec niri-session "$@"
      fi

      # Siehe Kopf der Datei: NIRI_CONFIG statt -c, weil niri.service das
      # Kommando selbst zusammensetzt.
      export NIRI_CONFIG="$generated"
      exec niri-session "$@"
    '';
  };

  # niri liest die Config, auf die NIRI_CONFIG zeigt -- also die Kopie, die
  # niri-smart beim Login angelegt hat. Ein `fr` aktualisiert nur die
  # HM-Config und wirkt deshalb erst beim naechsten Login. niri-reload baut
  # die Kopie neu und laesst niri sie per Dateiwaechter uebernehmen.
  #
  # Nebeneffekt, der Absicht ist: die GPU-Entscheidung wird dabei NEU
  # getroffen. Nach dem An- oder Abdocken zieht das den render-drm-device
  # also mit, ohne Abmelden.
  niriReload = pkgs.writeShellApplication {
    name = "niri-reload";
    runtimeInputs = with pkgs; [coreutils findutils gnugrep niri];
    text = ''
      ${gpuDecision}

      base="$HOME/.config/niri/config.kdl"
      # Muss WORTGLEICH mit dem Pfad in niri-smart sein: niri laeuft mit
      # NIRI_CONFIG=$generated aus niri-smarts Login, und dieses Script muss
      # exakt diese Datei atomar per mv ersetzen -- ein abweichender Pfad
      # wuerde NIRI_CONFIG ins Leere zeigen lassen. Neben der Basis, nicht in
      # $XDG_RUNTIME_DIR: siehe Kopfkommentar (relative includes aufloesen
      # sich gegen das Verzeichnis dieser Datei).
      generated="$HOME/.config/niri/.niri-smart.kdl"

      if [ ! -r "$base" ]; then
        printf 'niri-reload: %s nicht lesbar\n' "$base" >&2
        exit 1
      fi

      # Erst vollstaendig danebenbauen, pruefen, dann atomar ersetzen. Ein
      # halb geschriebenes Ziel wuerde der Dateiwaechter sofort einlesen.
      tmp="$generated.new"
      # rm zuerst: bleibt von einem abgebrochenen Lauf eine schreibgeschuetzte
      # Datei liegen, scheitert sonst jeder weitere Versuch an ihr. Und
      # install -m statt cp aus demselben Grund wie oben in niri-smart.
      rm -f "$tmp"
      install -m 0644 "$base" "$tmp"
      if [ -n "$render_node" ]; then
        {
          printf '\n// von niri-smart ergaenzt (%s)\n' "$mode"
          printf 'debug {\n    render-drm-device "%s"\n}\n' "$render_node"
        } >> "$tmp"
      fi

      if ! niri validate --config "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        printf 'niri-reload: erzeugte Config ist ungueltig, nichts geaendert\n' >&2
        exit 1
      fi

      mv "$tmp" "$generated"
      printf 'niri-reload: %s -- render-drm-device=%s\n' "$mode" "''${render_node:-unset}"
    '';
  };

  niriSmartSession =
    pkgs.runCommand "niri-smart-session" {
      passthru.providedSessions = ["niri-smart"];
    } ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/niri-smart.desktop <<'EOF'
      [Desktop Entry]
      Name=niri (Smart GPU)
      Comment=niri mit Auto-Erkennung der NVIDIA-GPU beim Docken
      Exec=niri-smart
      Type=Application
      EOF
    '';
in {
  environment.systemPackages = [niriSmart niriReload];
  services.displayManager.sessionPackages = [niriSmartSession];
}
