{
  pkgs,
  lib,
  ...
}: {
  programs.bat = {
    enable = true;
    config = {
      pager = "less -FR";
      # other styles available and cane be combined
      #  style = "numbers,changes,headers,rule,grid";
      style = "full";
      # Bat has other thems as well
      # ansi,Catppuccin,base16,base16-256,GitHub,Nord,etc
      # MODIFIED 2026-06-16: Dracula → Catppuccin Mocha for theme consistency
      # with Ghostty + Neovim + Starship.
      theme = lib.mkForce "Catppuccin Mocha";
    };
    extraPackages = with pkgs.bat-extras; [
      batman
      batpipe
      batgrep
    ];
  };
  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };
}
