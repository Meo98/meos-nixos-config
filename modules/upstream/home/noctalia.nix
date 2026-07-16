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
  host,
  ...
}: let
  bt-audio-monitor = import ../../meo/scripts/bt-audio-monitor.nix {inherit pkgs;};

  # MODIFIED 2026-07-16: Host-Variablen fuer idleScreenOff (Pfad-Tiefe: 3x ..
  # von modules/upstream/home/ zur Repo-Wurzel — vgl. hyprland/hyprland.nix mit 4x).
  vars = import ../../../hosts/${host}/variables.nix;

  # MODIFIED 2026-06-30: Session-Lock-Monitor-Patch ENTFERNT — upstream hat den
  # Bug gefixt (m_sessionLockIntegrationEnabled / ensureSessionLockMonitor). Der
  # noctalia-Input-Bump zog die Fix-Commits rein, wodurch unser lokaler Patch
  # als "Reversed (or previously applied)" fehlschlug und jeden Rebuild auf
  # beiden Hosts blockierte. Wie im Patch-Kommentar (2026-06-17) angekündigt:
  # bei upstream-Fix den overrideAttrs-Block ersatzlos raus, Paket direkt nutzen.
  # Patch-Datei bleibt unter noctalia-patches/ als Referenz liegen (nicht mehr
  # angewendet). Falls der Lockscreen-Bug wiederkehrt, hier reaktivieren.
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    package = noctaliaPkg;

    # Boot-defaults. The TOML is hot-reloaded by the daemon; runtime edits via
    # the Settings UI write back to ~/.config/noctalia/config.toml. Keep this
    # attrset to the values that must be correct on first boot or rebuild —
    # use the GUI for fine-tuning the rest. Validated against v5's example.toml
    # schema and noctalia config validate.
    settings = {
      theme = {
        # MODIFIED 2026-07-16: mkForce mode+source, weil Stylix-noctalia-Integration
        # (hm.nix) theme.mode/source selbst setzt -> sonst Konflikt beim Build.
        mode = pkgs.lib.mkForce "dark";
        source = pkgs.lib.mkForce "builtin";
        builtin = "Dracula";
      };

      shell = {
        # MODIFIED 2026-07-16: mkForce, weil neueres upstream-noctalia (hm.nix)
        # font_family selbst auf "Montserrat" setzt -> sonst Konflikt-Fehler beim Build.
        font_family = pkgs.lib.mkForce "JetBrains Mono";
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
        # MODIFIED 2026-07-08: mkForce, weil neueres upstream-noctalia (hm.nix)
        # notification.background_opacity=1.0 mit Normal-Prio hart setzt → sonst
        # "conflicting definition values" beim flake-update-rebuild (fu).
        background_opacity = pkgs.lib.mkForce 0.91;
      };

      osd = {
        position = "top_right";
        # MODIFIED 2026-07-16: mkForce, Stylix setzt osd.background_opacity selbst.
        background_opacity = pkgs.lib.mkForce 1.0;
      };

      # MODIFIED 2026-06-17: noctalia lockscreen wieder enabled. Original-SEGV
      # (`wl_display#1: error 0: invalid object` jede 11min am 12.06.) sollte
      # gefixt sein durch upstream-Commits seit unserem alten Pin: 7f6b7ce
      # (defer popup teardown to avoid Wayland destroy crash), 4a5d8c7 (fork
      # PAM auth into single-threaded child process), b1de9b2 (run PAM
      # off-thread). Wenn der SEGV wiederkommt: `enabled = false` setzen und
      # idle.behavior.lock.command zurück auf "hyprlock".
      lockscreen = {
        enabled = true;
      };

      audio = {
        enable_overdrive = true;
      };

      brightness = {
        enable_ddcutil = true;
      };

      # MODIFIED 2026-06-17: noctalia übernimmt wieder das Idle-Timing UND die
      # Lock-Rendering selbst. Lock FIRST (600s), DPMS-off SECOND (660s) — diese
      # Reihenfolge ist kritisch und der Grund warum die ursprüngliche Config
      # vom 12.06. das Lock-Surface auf einem DPMS-off Display zu acquirieren
      # versuchte (war 660s lock NACH 600s DPMS-off). hypridle bleibt nur noch
      # für die suspend-hooks (before_sleep_cmd lock, after_sleep_cmd DPMS-on),
      # listener blocks dort entfernt um Doppel-Timer zu vermeiden.
      idle.behavior.lock = {
        enabled = true;
        timeout = 600;
        command = "noctalia:session lock";
      };

      # MODIFIED 2026-07-01: screen-off deaktiviert als Workaround gegen den eDP-
      # Freeze auf `meo` (DPMS-off→on wedged die i915-Pipe/Power-Well des OLED,
      # kein Kernel-Fehler, live nicht loesbar, nur Reboot; PSR=0/FBC=0/DC=0 in
      # hosts/meo/default.nix kernelParams). Solange der Panel nie DPMS-off geht,
      # kann er nicht einfrieren. Lock (600s) bleibt aktiv.
      # MODIFIED 2026-07-16: per-Host via variables.nix idleScreenOff — der
      # Freeze betrifft nur meo (OLED); meo-work (IPS) schaltet den Screen bei
      # Idle wieder ab, statt ihn grundlos dauerhaft anzulassen.
      idle.behavior."screen-off" = {
        enabled = vars.idleScreenOff or false;
        timeout = 660;
        command = "noctalia:dpms-off";
        resume_command = "noctalia:dpms-on";
      };

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
