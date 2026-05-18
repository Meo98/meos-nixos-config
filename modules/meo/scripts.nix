{ pkgs, ... }: {
  # Custom helper scripts that get added to home.packages.
  # bt-audio-monitor is also referenced by modules/upstream/home/noctalia.nix
  # (as a systemd user service) — that reference is updated to use this same path.
  home.packages = [
    (import ./scripts/bt-audio-monitor.nix { inherit pkgs; })
    (import ./scripts/bt-audio-switch.nix  { inherit pkgs; })
    (import ./scripts/setup-secrets.nix    { inherit pkgs; })
    (import ./scripts/travel-mode.nix      { inherit pkgs; })
  ];
}
