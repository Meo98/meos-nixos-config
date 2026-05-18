{
  # Custom Hyprland helpers (volume, brightness, pyprland scratchpads).
  # Volume + brightness commands are referenced from modules/upstream/home/hyprland/binds.nix.
  imports = [
    ./hyprland/vol-smart.nix
    ./hyprland/bright-smart.nix
    ./hyprland/pyprland.nix
  ];
}
