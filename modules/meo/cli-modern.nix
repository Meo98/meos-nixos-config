# Modern CLI stack: Starship prompt + zoxide (smart cd) + atuin (history).
# eza and bat are already enabled via modules/upstream/home/{eza.nix,cli/bat.nix}.
{
  lib,
  pkgs,
  ...
}: {
  # Starship — override the upstream `enable = false` default.
  programs.starship = {
    enable = lib.mkForce true;
    enableZshIntegration = true;
    # Catppuccin Mocha palette (matches Ghostty + Neovim theme).
    settings = {
      add_newline = false;
      palette = lib.mkForce "catppuccin_mocha";
      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };

  # zoxide — smarter cd. Use with `z <hint>` or `zi` (interactive).
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # atuin — shell history with fzf-style picker. Local only; no cloud sync.
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = ["--disable-up-arrow"]; # keep zsh's up-arrow recall; only rebind Ctrl+R
    settings = {
      auto_sync = false;
      update_check = false;
      sync_frequency = "0";
      style = "compact";
      inline_height = 20;
      show_preview = true;
      keymap_mode = "vim-insert";
    };
  };
}
