# SDDM is a display manager for X11 and Wayland
{
  pkgs,
  config,
  lib,
  host,
  inputs,
  ...
}: let
  sddm-noctalia = pkgs.stdenv.mkDerivation {
    name = "sddm-noctalia-theme";
    src = inputs.sddm-noctalia;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/noctalia
      cp -r . $out/share/sddm/themes/noctalia/
      cp ${config.stylix.image} $out/share/sddm/themes/noctalia/Assets/background.png
    '';
  };
in {
  services.displayManager = {
    sddm = {
      package = pkgs.kdePackages.sddm;
      extraPackages = [sddm-noctalia];
      enable = true;
      wayland.enable = true;
      theme = "noctalia";
      settings = let
        vars = import ../../../hosts/${host}/variables.nix;
        keyboardLayout = vars.keyboardLayout or "us";
        keyboardVariant = vars.keyboardVariant or "";
      in {
        X11 = {
          XkbLayout = keyboardLayout;
          XkbVariant = keyboardVariant;
        };
      };
    };
  };

  # Ensure Wayland SDDM also sees XKB defaults
  systemd.services.display-manager.environment = let
    vars = import ../../../hosts/${host}/variables.nix;
    keyboardLayout = vars.keyboardLayout or "us";
    keyboardVariant = vars.keyboardVariant or "";
  in ({XKB_DEFAULT_LAYOUT = keyboardLayout;}
    // lib.optionalAttrs (keyboardVariant != "") {XKB_DEFAULT_VARIANT = keyboardVariant;});

  environment.systemPackages = [sddm-noctalia];
}
