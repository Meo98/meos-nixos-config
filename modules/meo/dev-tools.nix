{inputs, ...}: {
  # Prio 6 — Entwickler-/Convenience-Tooling.
  imports = [inputs.nix-index-database.hmModules.nix-index];

  # direnv + nix-direnv: pro Projekt ein .envrc → beim `cd` automatisch die
  # richtige DevShell (gecacht). .direnv/ ist bereits in .gitignore.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # nix-index: "command not found" schlaegt das passende Paket vor.
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  # comma: `, <tool>` fuehrt ein Programm ephemer aus, ohne es zu installieren.
  programs.nix-index-database.comma.enable = true;
}
