{host, ...}: let
  inherit (import ../../../hosts/${host}/variables.nix) animChoice;
in {
  imports = [
    animChoice
    ./binds.nix
    ./env.nix
    ./exec-once.nix
    ./hypridle.nix
    ./hyprland.nix
    ./hyprlock.nix
    ./pyprland.nix
    ./windowrules.nix
    ./vol-smart.nix
    ./bright-smart.nix
  ] ++ (if host == "meo" then [ ./affinity-gamescope.nix ] else []);
}
