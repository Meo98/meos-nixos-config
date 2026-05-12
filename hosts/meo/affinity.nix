{ config, pkgs, inputs, username, lib, ... }:

let
  vars = import ./variables.nix;
  enabled = (vars.enableAffinity or false);
in
lib.mkIf enabled {

  # ✅ Systemweit nötig für Wine/DXVK/Vulkan (auch wenn Affinity nur im User ist)
  hardware.graphics.enable = lib.mkDefault true;
  hardware.graphics.enable32Bit = lib.mkDefault true;

  # Vulkan Loader + Layers (optional, aber hilfreich)
  hardware.graphics.extraPackages = with pkgs; [
    vulkan-loader
    vulkan-validation-layers
  ];

  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
    vulkan-loader
  ];

  # Tools zum Debuggen (du hattest "vulkaninfo: command not found")
  environment.systemPackages = with pkgs; [
    vulkan-tools
  ];

  environment.sessionVariables = {
    # vkd3d freeze fix auf Intel iGPU (Shader-Kompilierungs-Hang)
    VKD3D_CONFIG = "no_upload_hvv";

    # Ersetzt Wine's Busy-Wait durch Kernel-Futexes → verhindert 100% CPU Deadlock
    # (zen-Kernel 6.19 unterstützt beides vollständig)
    WINEFSYNC = "1";
    WINESYNC = "1";
  };

  # Affinity 3.x (Canva) versucht beim Start Dynamic Config von Canva-Servern zu laden.
  # Unter Wine hängt der DNS-Lookup bis zum Timeout (~30s) und friert die App ein.
  # Mit 127.0.0.1 scheitert die Verbindung sofort statt zu warten.
  networking.extraHosts = ''
    127.0.0.1 affinity-client-config-public.canva.com
    127.0.0.1 canva.com
    127.0.0.1 api.canva.com
  '';

  # ✅ Affinity nur im User-Profil (Home Manager)
  home-manager.users.${username}.home.packages =
    lib.optionals enabled [
      inputs.affinity-nix.packages.${pkgs.system}.v3
    ];
}
