# Randspalten verbreitern: Dienst zum Daemon in
# modules/meo/scripts/niri-edge-width-daemon.nix.
#
# Setzt Breite UND Ausrichtung der fokussierten Spalte nach ihrer Position:
# Randspalten buendig am Bildschirmrand mit der Luecke nach innen, mittlere
# Spalten zentriert. Haengt untrennbar mit center-focused-column = "never"
# in layout.nix zusammen — ohne den Dienst wird gar nichts mehr zentriert.
# Deshalb Restart=always. Begruendung und Zahlen im Kopf des Daemons.
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

        # Breiten als proportion-Prozent, dieselbe Einheit wie
        # default-column-width in layout.nix. Die sichtbaren Kachelbreiten
        # sind etwas kleiner, weil die gaps abgehen: 100 -> 98.95 %,
        # 91.667 -> 90.70 %, 83.333 -> 82.38 % (am laufenden System
        # nachgerechnet, siehe Kopf des Daemons).
        #
        #   SINGLE  einzige Spalte im Workspace: fuellt den Schirm.
        #   EDGE    erste oder letzte: buendig am Bildschirmrand, die Luecke
        #           liegt innen beim Nachbarn.
        #   MIDDLE  dazwischen: zentriert, wie bisher.
        "NIRI_EDGE_WIDTH_SINGLE=100%"
        "NIRI_EDGE_WIDTH_EDGE=91.667%"
        "NIRI_EDGE_WIDTH_MIDDLE=83.333%"
      ];
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
