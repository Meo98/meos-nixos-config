# Dashboard-Terminal: erscheint automatisch links vom ersten Fenster eines
# Workspace und verschwindet mit dem letzten.
#
# Die zugehoerige FENSTERREGEL steht bewusst NICHT hier, sondern in rules.nix.
# Grund: settings._children wird zwar ueber Modulgrenzen hinweg konkateniert,
# die Reihenfolge dabei ist aber nicht garantiert — und bei niri gewinnt die
# ZULETZT passende Regel. Eine Regel in einer zweiten Datei waere ein
# Muenzwurf. Siehe Kopfkommentar von rules.nix.
{pkgs, ...}: let
  display = import ../scripts/niri-dashboard.nix {inherit pkgs;};
  daemon = import ../scripts/niri-dashboard-daemon.nix {inherit pkgs;};
in {
  home.packages = [display daemon];

  systemd.user.services.niri-dashboard = {
    Unit = {
      Description = "Dashboard-Spalte automatisch pro niri-Workspace";
      # Ohne laufenden Compositor gibt es keinen Event-Stream. niri.service
      # zieht graphical-session.target erst durch sein eigenes Starten hoch
      # (BindsTo+Before im niri-Paket, share/systemd/user/niri.service), das
      # Target allein reicht als Ordnungskriterium also nicht.
      After = ["niri.service"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${daemon}/bin/niri-dashboard-daemon";

      # Der Daemon beendet sich absichtlich, wenn der Event-Stream endet —
      # also wenn niri weg ist oder neu startet. Statt eigener Wiederanlauf-
      # Logik uebernimmt das systemd; beim Verbinden baut WindowsChanged den
      # Zustand ohnehin komplett neu auf.
      Restart = "always";
      RestartSec = 2;

      # Der Daemen startet kitty. Ohne PATH-Eintrag findet er es nicht, weil
      # systemd-User-Units nicht die Login-Shell erben.
      Environment = [
        "PATH=${pkgs.kitty}/bin:${pkgs.niri}/bin:${display}/bin"
      ];
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
