{inputs, ...}: {
  nixpkgs.overlays = [
    # Provide pkgs.google-antigravity via antigravity-nix overlay
    inputs.antigravity-nix.overlays.default
    # awww (swww-Nachfolger) aus dem offiziellen Flake
    (final: prev: {
      awww = inputs.awww.packages.${prev.system}.default;
    })
    # affinity-nix: makes pkgs.affinity-v3 available (recommended approach)
    # inputs.affinity-nix.overlays.default
  ];
}
