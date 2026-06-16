{...}: {
  # MODIFIED 2026-06-16: hypridle wieder eingeführt nach Noctalia-v5-Idle-Daemon
  # Race. Reihenfolge ist entscheidend: LOCK ZUERST (acquire wlr-session-lock auf
  # aktivem Display), DPMS-off DANACH. Vorher hatte Noctalia die Reihenfolge
  # invertiert (DPMS-off bei 600s, lock bei 660s) — hyprlock konnte sein Lock-
  # Surface nicht sauber auf einem DPMS-off Display acquirieren, was den
  # "stuck in hyprlock"-Bug verursachte. ZaneyOS upstream macht es identisch
  # (siehe /tmp/zaneyos-v5/modules/home/hyprland/hypridle.nix).
  #
  # KEINE `hyprctl reload`-Calls — die hatten 2026-06-12 monitor-scale regression
  # 1.6× → 1.0× auf eDP-1 ausgelöst. Nur `dispatch dpms on/off` ist scale-safe.
  services.hypridle = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = {
      general = {
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
      };
      listener = [
        {
          timeout = 600;
          on-timeout = "pidof hyprlock || hyprlock";
        }
        {
          timeout = 660;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
