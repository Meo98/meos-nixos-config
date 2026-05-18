{ pkgs, inputs, username, lib, host, ... }:

let
  # Resolve variables.nix relative to the actual host being built. The `host`
  # specialArg is set in flake.nix per host (e.g. "meo" or "meo-work"), so
  # importing affinity.nix from a different host directory still picks up the
  # right variables.nix.
  hostVars = import (../. + "/${host}/variables.nix");
  enabled = (hostVars.enableAffinity or false);
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
