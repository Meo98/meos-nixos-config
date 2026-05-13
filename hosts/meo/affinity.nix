{ pkgs, inputs, username, lib, ... }:

let
  vars = import ./variables.nix;
  enabled = (vars.enableAffinity or false);
in
lib.mkIf enabled {

  hardware.graphics.enable = lib.mkDefault true;
  hardware.graphics.enable32Bit = lib.mkDefault true;

  # Affinity 3.x versucht beim Start Canva-Server zu erreichen.
  # Ohne diesen Fix hängt der DNS-Lookup ~30s beim Startup.
  networking.extraHosts = ''
    127.0.0.1 affinity-client-config-public.canva.com
    127.0.0.1 canva.com
    127.0.0.1 api.canva.com
  '';

  home-manager.users.${username}.home.packages = lib.optionals enabled [
    pkgs.affinity-v3
  ];
}
