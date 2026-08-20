{
  # Custom home-manager modules added on top of modules/upstream/home/.
  # This file is imported via hosts/{meo,meo-work}/default.nix as:
  #   home-manager.users.${username}.imports = [ ../../modules/meo ];
  imports = [
    # trading-bot.nix entfernt 2026-07-16: Matrix-Quant-Bot wird nicht mehr
    # benoetigt (User-Entscheid). Datei geloescht; Historie via git log --follow.
    ./hyprland.nix
    ./scripts.nix
    ./pdf-tools.nix
    ./cad-tools.nix
    ./nvim-yazi-tweaks.nix
    ./micropython.nix
    ./bun.nix
    ./cli-modern.nix
    ./automation-health.nix
    ./update-prewarm.nix
    ./dev-tools.nix
    ./termfilechooser.nix
  ];
}
