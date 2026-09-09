# niri-pip — Picture-in-Picture automatisch schwebend halten.
#
# Erkennt Browser-PiP-Fenster selbst (Detektoren nach Titel, app-id, Groesse
# und Seitenverhaeltnis), haelt sie schwebend, laesst sie dem Workspace-
# Wechsel folgen — und zwar mit focus=false, stiehlt also nie die Tastatur —
# und merkt sich Groesse und Position ueber Neustarts hinweg.
#
# WARUM NICHT piris sticky-Plugin: das verlangt ein bereits SCHWEBENDES,
# fokussiertes Fenster, haelt nur EINES gleichzeitig und vergisst es, sobald
# der Daemon neu startet. Es ist damit deutlich manueller. piri bleibt fuer
# singleton zustaendig (modules/meo/niri/piri.nix), sein sticky ist aus.
#
# KEINE KONFIGURATIONSDATEI, ABSICHTLICH. config/config.example.toml des
# Projekts bildet exakt die eingebauten Vorgaben ab — auto_detect an,
# follow-workspace, Position unten rechts, Profil "medium", und die
# Browser-Detektoren fuer Vivaldi sind an. Eine Datei zu schreiben, die nur
# die Vorgaben wiederholt, brächte nichts ausser einer Stelle, die bei einem
# Versionswechsel veraltet. Zum Abschmecken:
#   cp ${pkgs-Pfad}/config/config.example.toml ~/.config/niri-pip/config.toml
# Die Datei gehoert dann DIR, nicht Nix — niri-pip liest sie nur.
#
# Gelernte Groessen und Positionen liegen getrennt davon in
# ~/.local/state/niri-pip/state.json und werden allein vom Daemon
# geschrieben. Diese Datei wird hier bewusst NICHT deklariert; das waere
# derselbe Fehler wie frueher bei DankMaterialShells settings.json.
{
  inputs,
  pkgs,
  ...
}: let
  niriPip = import ../scripts/niri-pip.nix {
    inherit pkgs;
    src = inputs.niri-pip;
  };
in {
  home.packages = [niriPip];

  systemd.user.services.niri-pip = {
    Unit = {
      Description = "niri-pip — Picture-in-Picture-Regler";
      Documentation = ["https://github.com/t1ktakdev/niri-pip"];
      After = ["niri.service"];
      PartOf = ["graphical-session.target"];

      # Die mitgelieferte Unit des Projekts hat zusaetzlich
      # ConditionEnvironment=NIRI_SOCKET. Hier bewusst weggelassen: eine
      # nicht erfuellte Condition laesst systemd die Unit still als
      # "inactive" ueberspringen statt sie als gescheitert zu melden — man
      # sucht den Fehler dann an der falschen Stelle. After=niri.service und
      # Restart=always erreichen dasselbe, nur sichtbar.
    };

    Service = {
      ExecStart = "${niriPip}/bin/niripipd";
      ExecReload = "${niriPip}/bin/niripip reload";
      Restart = "always";
      RestartSec = 1;
      TimeoutStopSec = 5;
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
