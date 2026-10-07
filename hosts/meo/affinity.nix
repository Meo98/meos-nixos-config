{ pkgs, inputs, username, lib, host, ci ? false, ... }:

let
  # Resolve variables.nix relative to the actual host being built. The `host`
  # specialArg is set in flake.nix per host (e.g. "meo" or "meo-work"), so
  # importing affinity.nix from a different host directory still picks up the
  # right variables.nix.
  hostVars = import (../. + "/${host}/variables.nix");
  # `ci` (specialArg from flake.nix) is true for the `*-ci` configurations that
  # build.yml builds. Affinity's wine-wow64 is in no binary cache and takes
  # hours on a GitHub runner, so CI skips it. Local `fr` builds are unaffected.
  enabled = (hostVars.enableAffinity or false) && !ci;
in
lib.mkIf enabled {

  # Wine braucht 32-bit Graphics-Stack für einige Affinity-Calls
  hardware.graphics.enable = lib.mkDefault true;
  hardware.graphics.enable32Bit = lib.mkDefault true;

  # Affinity v3 (Canva-owned) versucht beim Start einen Config-Check gegen
  # affinity-client-config-public.canva.com — wenn der nicht resolved, hängt
  # der Startup ~30s am DNS-Lookup. Block NUR diesen Endpoint.
  #
  # WICHTIG: Wir blocken NICHT canva.com oder api.canva.com — die werden für
  # den OAuth-Login (Canva-Account) gebraucht. Mit zu breitem Block kann man
  # sich in Affinity nicht einloggen.
  networking.extraHosts = ''
    127.0.0.1 affinity-client-config-public.canva.com
  '';

  # Available packages from Meo98/affinity-nix-fork overlay (siehe flake.nix):
  #   pkgs.affinity-v3        — v3 unified app (current, recommended; gepatcht für iGPU)
  #   pkgs.affinity-photo     — v2 Photo (upstream, ungetestet mit fork-patches)
  #   pkgs.affinity-designer  — v2 Designer (upstream, ungetestet)
  #   pkgs.affinity-publisher — v2 Publisher (upstream, ungetestet)
  home-manager.users.${username}.home.packages = [
    pkgs.affinity-v3
  ];
}
