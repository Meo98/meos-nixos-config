{pkgs, ...}: {
  home.packages = with pkgs; [zsh];

  home.file."./.zshrc-personal".text = ''

    # This file allows you to define your own aliases, functions, etc
    # below are just some examples of what you can use this file for

      #!/usr/bin/env zsh
      # Set defaults
      #
      #export EDITOR="nvim"
      #export VISUAL="nvim"

      #alias c="clear"

      # Load local secrets (not tracked by git)
      [[ -f ~/.zshrc-secrets ]] && source ~/.zshrc-secrets

  '';
}
