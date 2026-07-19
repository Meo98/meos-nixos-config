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
          # MODIFIED: 0.8 → 1.0 (neutral; vorher künstlich gebremst)
          scroll_factor = 1.0;
        };
      };

      # Hyprland 0.54+: nur "workspace" als Aktion verfügbar
      gesture = [ "3, horizontal, workspace" ];

      decoration = {
        rounding = 10;
        shadow.enabled = true;
        # MODIFIED 2026-07-15: Blur von passes=3/size=6 auf passes=1/size=5 reduziert.
        # Ursache Tipp-/Scroll-Ruckeln auf meo-work (Iris Xe treibt 3 Displays):
        # blur passes=3 tastet pro Frame 3x den Framebuffer ab = teuerste iGPU-Last.
        # Live-Test (blur aus) brachte spuerbare Besserung; passes=1 behaelt den Glas-Look.
        blur = {
          enabled = true;
          size = 5;
          passes = 1;
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
        # MODIFIED 2026-07-18: erlaubt einem neuen ext-session-lock-Client die
        # Sperre zu uebernehmen, wenn der alte Lock-Client (noctalia) stirbt
        # oder neu gestartet wird. Ohne das bleibt die Session nach einem
        # noctalia-Restart im Locked-Zustand ohne entsperrbaren Lockscreen.
        # Noetig fuer das Resume-Recovery in hypridle.nix.
        allow_session_lock_restore = true;
      };
    };

    extraConfig = ''
      ${vars.extraMonitorSettings}
      monitor=,preferred,auto,auto
      monitor=Virtual-1,1920x1080@60,auto,1
    '';
  };
}
