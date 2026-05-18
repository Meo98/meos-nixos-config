{
  # Custom home-manager modules added on top of modules/upstream/home/.
  # This file is imported via hosts/{meo,meo-work}/default.nix as:
  #   home-manager.users.${username}.imports = [ ../../modules/meo ];
  imports = [
    ./trading-bot.nix
    ./hyprland.nix
    ./scripts.nix
  ];
}
