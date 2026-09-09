# Randspalten verbreitern: Dienst zum Daemon in
# modules/meo/scripts/niri-edge-width-daemon.nix.
#
# Steht die fokussierte Spalte am linken oder rechten Ende ihres Workspace,
# bekommt sie den Platz, der dort sonst leer bliebe. Die Begruendung der
# Zahlen steht im Kopf des Daemons.
{pkgs, ...}: let
  daemon = import ../scripts/niri-edge-width-daemon.nix {inherit pkgs;};
in {
  home.packages = [daemon];

  systemd.user.services.niri-edge-width = {
    Unit = {
      Description = "Fokussierte Randspalte in niri verbreitern";
      # Wie beim frueheren Dashboard-Dienst: niri.service zieht
      # graphical-session.target erst durch sein eigenes Starten hoch, das
      # Target allein reicht als Ordnungskriterium also nicht.
      After = ["niri.service"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${daemon}/bin/niri-edge-width-daemon";

      # Der Daemon beendet sich, wenn der Event-Stream endet — also wenn niri
      # weg ist oder neu startet. Den Wiederanlauf macht systemd.
      Restart = "always";
      RestartSec = 2;

      # systemd-User-Units erben nicht die Login-Shell.
      Environment = [
        "PATH=${pkgs.niri}/bin"

        # Zuschlaege in Prozent der Bildschirmbreite. Zum Abschmecken hier
        # aendern, nicht im Daemon:
        #   SINGLE: einzige Spalte im Workspace. 16.667 = 1/6 hebt die
        #           Standardbreite 5/6 auf volle Breite.
        #   EDGE:   erste oder letzte von mehreren. 8.333 = 1/12 halbiert den
        #           toten Aussenrand; weil zentriert wird, halbiert es
        #           zugleich den Guckstreifen zur Nachbarspalte. Wer den
        #           Streifen ganz aufgeben will, setzt hier ebenfalls 16.667.
        "NIRI_EDGE_BONUS_SINGLE=16.667"
        "NIRI_EDGE_BONUS_EDGE=8.333"
      ];
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
