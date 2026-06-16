# MODIFIED: 2026-06-12 — full rewrite for Noctalia v5 (alpha).
# v5 is a native C++ Wayland shell, no Qt/Quickshell, config is TOML at
# ~/.config/noctalia/config.toml. The official home-manager module from
# inputs.noctalia.homeModules.default handles the systemd service, package,
# and TOML generation. Previously this file:
#   - ran a custom systemd-user-service pointing at bin/noctalia-shell
#   - seeded a QML config tree into ~/.config/quickshell/noctalia-shell/
#   - sed-patched AudioService.qml to call `wpctl set-default` after sink change
# All three are obsolete in v5: binary is now `noctalia`, there is no QML tree,
# and v5 sets the pipewire default-sink natively via pw_metadata (see
# src/pipewire/pipewire_service.cpp upstream).
{
  pkgs,
  inputs,
  ...
}: let
  bt-audio-monitor = import ../../meo/scripts/bt-audio-monitor.nix {inherit pkgs;};
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = false;

    # Boot-defaults. The TOML is hot-reloaded by the daemon; runtime edits via
    # the Settings UI write back to ~/.config/noctalia/config.toml. Keep this
    # attrset to the values that must be correct on first boot or rebuild —
    # use the GUI for fine-tuning the rest. Validated against v5's example.toml
    # schema and noctalia config validate.
    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Dracula";
      };

      shell = {
        font_family = "JetBrains Mono";
        ui_scale = 1.05;
        corner_radius_scale = 1.09;
        time_format = "{:%H:%M}";
        avatar_path = "~/.face.icon";
        polkit_agent = true;
        clipboard_enabled = true;
        clipboard_history_max_entries = 100;
      };

      shell.animation = {
        enabled = true;
        speed = 1.0;
      };

      bar.main = {
        position = "top";
        background_opacity = 0.56;
        radius = 12;
        margin_h = 15;
        margin_v = 5;
        widget_spacing = 6;
        capsule = true;
        capsule_opacity = 0.39;
        shadow = true;
        reserve_space = true;
      };

      wallpaper = {
        enabled = true;
        directory = "~/Pictures/Wallpapers";
        fill_mode = "crop";
        transition_duration = 1500;
      };

      wallpaper.automation = {
        enabled = true;
        interval_minutes = 5;
        order = "random";
        recursive = true;
      };

      location = {
        auto_locate = false;
        address = "Zürich";
      };

      nightlight = {
        enabled = false;
        temperature_day = 6500;
        temperature_night = 4000;
      };

      dock = {
        enabled = true;
        position = "bottom";
        pinned = ["vivaldi-stable" "antigravity" "tidal-hifi"];
      };

      notification = {
        enable_daemon = true;
        show_app_name = true;
        show_actions = true;
        layer = "top";
        background_opacity = 0.91;
      };

      osd = {
        position = "top_right";
        background_opacity = 1.0;
      };

      # MODIFIED 2026-06-13: noctalia v5 alpha lock screen ist instabil — jeder
      # lock-cycle SEGV't den Prozess mit `wl_display#1: error 0: invalid object`.
      # In 80min am 12.06. waren das 5 Crashes hintereinander bis xdg-desktop-
      # portal mit cascaded und SDDM die Session nicht mehr authentifizieren
      # konnte → reboot war der einzige Ausweg. Stattdessen hyprlock (mature,
      # designed-for-Hyprland) als externen Lock-Process spawnen.
      lockscreen = {
        enabled = false;
      };

      audio = {
        enable_overdrive = true;
      };

      brightness = {
        enable_ddcutil = true;
      };

      # MODIFIED 2026-06-16: idle.behavior.{lock,screen-off} komplett entfernt.
      # Symptom war "stuck in hyprlock" nach idle: Noctalia hatte DPMS-off bei
      # 600s und lock bei 660s — also Display tot BEVOR hyprlock sein Lock-
      # Surface acquirieren konnte. hypridle übernimmt jetzt die Idle-Chain
      # mit der richtigen Reihenfolge (lock zuerst, DPMS-off danach) und einem
      # `after_sleep_cmd` der DPMS nach suspend zurückholt.
      # Siehe modules/upstream/home/hyprland/hypridle.nix.

      weather = {
        enabled = true;
        unit = "celsius";
        effects = true;
      };
    };
  };

  # Monitor Hot-Plug: Layout wiederherstellen wenn Bildschirm angeschlossen wird.
  # Orthogonal to Noctalia — keeps Hyprland's monitor layout sane on hotplug.
  home.file.".local/bin/hypr-monitor-hotplug" = {
    executable = true;
    text = ''
      #!/bin/sh
      export PATH=/run/current-system/sw/bin:/etc/profiles/per-user/meo/bin:$PATH
      SOCK=$(ls /run/user/1000/hypr/ 2>/dev/null | head -1)
      socat - UNIX-CONNECT:/run/user/1000/hypr/$SOCK/.socket2.sock | \
        while read -r line; do
          case "$line" in
            monitoradded*)
              sleep 2
              hyprctl dispatch dpms on
              hyprctl reload
              ;;
          esac
        done
    '';
  };

  systemd.user.services.hyprland-monitor-hotplug = {
    Unit = {
      Description = "Restore Hyprland monitor layout on hotplug";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "%h/.local/bin/hypr-monitor-hotplug";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  # Bluetooth audio auto-switch: lauscht auf BT-Connect-Events und routet
  # Audio automatisch auf das verbindende Gerät um (wie macOS/Windows).
  # Orthogonal to Noctalia.
  systemd.user.services.bt-audio-monitor = {
    Unit = {
      Description = "Bluetooth audio auto-switch monitor";
      After = ["graphical-session.target" "pipewire.service"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${bt-audio-monitor}/bin/bt-audio-monitor";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
