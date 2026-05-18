{
  host,
  config,
  pkgs,
  lib,
  ...
}: let
  vars = import ../../../../hosts/${host}/variables.nix;
  hyprKbLayout = "ch";
  hyprKbVariant = "de";
in {
  home.packages = with pkgs; [
    awww
    grim
    slurp
    wl-clipboard
    swappy
    ydotool
    hyprpolkitagent
    hyprshot
    hyprpicker
  ];
  
  systemd.user.targets.hyprland-session.Unit.Wants = [
    "xdg-desktop-autostart.target"
  ];
  
  home.file = {
    "Pictures/Wallpapers" = {
      source = ../../../../wallpapers;
      recursive = true;
    };
    ".face.icon".source = ./face.jpg;
    ".config/face.jpg".source = ./face.jpg;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    
    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = ["--all"];
    };
    
    xwayland = {
      enable = true;
    };

    settings = {
      "$mod" = "SUPER";

      xwayland = {
        force_zero_scaling = true;
      };

      exec-once = [
        "systemctl --user start gnome-keyring-daemon"
        "/home/meo/keyball-layer-popup/start.sh"
      ];


      general = {
        layout = "dwindle";
        gaps_in = 6;
        gaps_out = 8;
        border_size = 2;
        resize_on_border = true;
        "col.active_border" = "rgb(${config.lib.stylix.colors.base08}) rgb(${config.lib.stylix.colors.base0C}) 45deg";
        "col.inactive_border" = "rgb(${config.lib.stylix.colors.base01})";
      };

      cursor = {
        inactive_timeout = 3;
        hide_on_key_press = true;
      };

      input = {
        kb_layout = hyprKbLayout;
        kb_options = "grp:alt_caps_toggle";
        numlock_by_default = true;
        repeat_delay = 300;
        follow_mouse = 1;
        float_switch_override_focus = 0;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          scroll_factor = 0.8;
        };
      };

      # Hyprland 0.54+: nur "workspace" als Aktion verfügbar
      gesture = [ "3, horizontal, workspace" ];

      decoration = {
        rounding = 10;
        shadow.enabled = true;
        blur = {
          enabled = true;
          size = 6;
          passes = 3;
        };
      };

      misc = {
        layers_hog_keyboard_focus = true;
        initial_workspace_tracking = 0;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        enable_swallow = false;
        # MODIFIED 2026-05-18: misc:vfr was removed in Hyprland 0.54.x (no
        # backward compat). misc:vrr (Variable Refresh Rate) below is the
        # remaining refresh-related option and still valid.
        vrr = 2;
      };
    };

    extraConfig = ''
      ${vars.extraMonitorSettings}
      monitor=,preferred,auto,auto
      monitor=Virtual-1,1920x1080@60,auto,1
    '';
  };
}
