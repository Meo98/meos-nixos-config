# DankMaterialShell — Einstieg. Wird von modules/upstream/home/default.nix
# importiert, wenn barChoice = "dms" in hosts/<host>/variables.nix steht.
#
# Spec: docs/superpowers/specs/2026-08-31-dms-migration-design.md
{inputs, ...}: {
  imports = [
    inputs.dank-material-shell.homeModules.dank-material-shell
    ./settings.nix
    ./niri.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
  };
}
