# Monitor-Konfiguration.
#
# Uebernommen aus hosts/meo/variables.nix extraMonitorSettings:
#   monitor = eDP-1,2560x1600@240,0x0,1.6
#   monitor = DP-1,preferred,1600x141,1.2
#
# niri rechnet Positionen in LOGISCHEN Koordinaten. 2560 / 1.6 = 1600, deshalb
# liegt DP-1 bei x=1600 — dieselbe Zahl wie in der Hyprland-Zeile.
#
# DP-1 bekommt bewusst kein mode: ohne Angabe waehlt niri den bevorzugten Modus
# ("preferred" in der Hyprland-Notation).
#
# Reihenfolge der output-Bloecke ist bedeutungslos, deshalb duerfen sie in einer
# eigenen Datei liegen (anders als window-rule, siehe rules.nix).
{...}: {
  wayland.windowManager.niri.settings._children = [
    {
      output = {
        _args = ["eDP-1"];
        mode = "2560x1600@240.000";
        scale = 1.6;
        position._props = {
          x = 0;
          y = 0;
        };
      };
    }
    {
      output = {
        _args = ["DP-1"];
        scale = 1.2;
        position._props = {
          x = 1600;
          y = 141;
        };
      };
    }
  ];
}
