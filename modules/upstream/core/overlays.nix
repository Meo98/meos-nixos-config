{inputs, ...}: {
  nixpkgs.overlays = [
    # Provide pkgs.google-antigravity via antigravity-nix overlay
    inputs.antigravity-nix.overlays.default
    # awww (swww-Nachfolger) aus dem offiziellen Flake
    (final: prev: {
      awww = inputs.awww.packages.${prev.system}.default;
    })
  ];
}
