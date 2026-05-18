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

  # Wine braucht 32-bit Graphics-Stack für einige Affinity-Calls
  hardware.graphics.enable = lib.mkDefault true;
  hardware.graphics.enable32Bit = lib.mkDefault true;

  # Affinity v3 (Canva-owned) versucht beim Start canva.com zu erreichen.
  # Ohne diesen Block hängt der DNS-Lookup ~30s beim Startup.
  networking.extraHosts = ''
    127.0.0.1 affinity-client-config-public.canva.com
    127.0.0.1 canva.com
    127.0.0.1 api.canva.com
  '';

  # Available packages from mrshmllow/affinity-nix overlay:
  #   pkgs.affinity-v3        — v3 unified app (current, recommended)
  #   pkgs.affinity-photo     — v2 Photo
  #   pkgs.affinity-designer  — v2 Designer
  #   pkgs.affinity-publisher — v2 Publisher
  home-manager.users.${username}.home.packages = [
    pkgs.affinity-v3
  ];
}
