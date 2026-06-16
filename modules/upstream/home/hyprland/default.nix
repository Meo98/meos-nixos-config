{host, ...}: let
  inherit (import ../../../../hosts/${host}/variables.nix) animChoice;
in {
  # MODIFIED 2026-06-16: hypridle wieder rein. Vorgängerversuch am 2026-06-12,
  # Noctalia v5's eingebauten idle daemon zu nutzen, hat in stuck-lockscreen
  # gemündet (DPMS-off vor lock → hyprlock konnte Lock-Surface auf totem Display
  # nicht acquirieren). Lösung: ZaneyOS-Pattern wiederherstellen, Noctalia nur
  # noch als Shell/Bar, hypridle steuert lock + DPMS in der RICHTIGEN Reihenfolge.
  # Monitor-scale regression von früher ist hier kein Risiko mehr — neue
  # hypridle.nix nutzt ausschließlich `dispatch dpms on/off`, kein `hyprctl reload`.
  imports = [
    animChoice
    ./binds.nix
    ./env.nix
    ./exec-once.nix
    ./hypridle.nix
    ./hyprland.nix
    ./hyprlock.nix
    ./windowrules.nix
  ];
}
