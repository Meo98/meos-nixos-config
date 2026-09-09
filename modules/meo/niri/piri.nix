# piri — Erweiterungs-Daemon fuer niri. Ersetzt zwei Einzelwerkzeuge.
#
# Von den neun Plugins sind bewusst nur ZWEI an:
#
#   singleton  fokussiert eine laufende Instanz, statt eine zweite zu
#              starten. Das ist die Aufgabe, fuer die sonst niri-ror
#              gebraucht worden waere.
# Sein sticky-Plugin war zunaechst ebenfalls an, ist aber wieder aus: es
# verlangt ein bereits schwebendes, fokussiertes Fenster, haelt nur EINES
# gleichzeitig und vergisst es beim Neustart des Daemons. Fuer
# Picture-in-Picture macht niri-pip dasselbe automatisch, siehe
# modules/meo/niri/niri-pip.nix.
#
# WAS SICH SPARSAMER LIEST ALS ES IST: workspace_rule bleibt AUS, obwohl es
# verlockend klingt. Sein auto_width setzt Spaltenbreiten nach Fensteranzahl
# und sein auto_maximize maximiert das einzige Fenster eines Workspace — beides
# wuerde sich mit modules/meo/niri/edge-width.nix um dieselben Spalten
# streiten. Zwei Regelwerke auf einer Groesse ist ein Fehler, kein Feature.
# Wer spaeter workspace_rule will, schaltet zuerst edge-width.nix ab.
#
# Die uebrigen (scratchpads, empty, window_rule, window_order, swallow, mark)
# sind aus, weil sie hier niemand angefordert hat und jedes davon eigenes
# Verhalten mitbringt. Sie stehen unten auskommentiert bereit.
#
# ZUR KONFIGURATIONSDATEI: piri LIEST ~/.config/niri/piri.toml nur, es
# schreibt sie nie zurueck (Scratchpad-, Mark- und Sticky-Zustand liegen laut
# Dokumentation ausschliesslich im Arbeitsspeicher). Sie darf deshalb ein
# Store-Symlink sein — anders als DankMaterialShells settings.json, siehe
# modules/meo/dms/settings.nix.
{
  inputs,
  config,
  pkgs,
  host,
  ...
}: let
  vars = import ../../../hosts/${host}/variables.nix;
  inherit (vars) browser;

  piri = inputs.piri.packages.${pkgs.stdenv.hostPlatform.system}.default;

  tomlFormat = pkgs.formats.toml {};

  settings = {
    piri.plugins = {
      singleton = true;

      # Sticky ist AUS: es verlangt ein bereits schwebendes, fokussiertes
      # Fenster, haelt nur eines und vergisst es beim Neustart des Daemons.
      # Fuer Picture-in-Picture uebernimmt das automatische niri-pip,
      # siehe modules/meo/niri/niri-pip.nix.
      sticky = false;

      scratchpads = false;
      empty = false;
      window_rule = false;
      window_order = false;
      swallow = false;
      mark = false;
      # Siehe Kopfkommentar: streitet mit edge-width.nix.
      workspace_rule = false;
    };

    # Fenster, von denen es nur eines geben soll. `piri singleton <name>
    # toggle` fokussiert das vorhandene oder startet es.
    #
    # app_id ist optional — ohne Angabe leitet piri sie aus dem
    # Kommandonamen ab. Das reicht fuer gimp, obs und discord, deren
    # StartupWMClass in den Desktop-Dateien genau so lautet (geprueft
    # 2026-09-09). Vivaldi braucht eine eigene: das Kommando heisst
    # "vivaldi", das Fenster meldet sich aber als "vivaldi-stable".
    singleton = {
      browser = {
        command = browser;
        app_id = "^vivaldi";
      };
      gimp.command = "gimp";
      obs.command = "obs";
      discord.command = "discord";
    };
  };
in {
  home.packages = [piri];

  xdg.configFile."niri/piri.toml".source =
    tomlFormat.generate "piri.toml" settings;

  systemd.user.services.piri = {
    Unit = {
      Description = "piri — niri-Erweiterungen (singleton, sticky)";
      # Wie bei edge-width.nix: niri.service zieht graphical-session.target
      # erst durch sein eigenes Starten hoch.
      After = ["niri.service"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${piri}/bin/piri daemon";
      Restart = "on-failure";
      RestartSec = 2;

      # singleton STARTET Programme. Ohne PATH findet der Dienst weder
      # vivaldi noch gimp — systemd-User-Units erben die Login-Shell nicht.
      # Das eigene NixOS-Modul des Projekts setzt enableDefaultPath = false
      # und keinen Ersatz; deshalb hier ein eigener Dienst statt dessen.
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:${pkgs.niri}/bin"
      ];
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
