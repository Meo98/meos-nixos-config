{...}: {
  # MODIFIED 2026-06-17: hypridle reduziert auf REINEN suspend-handler.
  # Idle-Timing + Lock-Rendering machen jetzt noctalia v5 selbst (siehe
  # modules/upstream/home/noctalia.nix idle.behavior.{lock,screen-off} + die
  # lockscreen.enabled=true). hypridle existiert nur noch um:
  #   - vor suspend `loginctl lock-session` zu feuern (triggert noctalia's
  #     logind Lock-Listener → noctalia rendert sein Lockscreen-Surface)
  #   - nach resume `hyprctl dispatch dpms on` zu feuern (DPMS recovery, da
  #     noctalia v5's PrepareForSleep-Callback bei sleeping=false nur Bluetooth
  #     und Nightlight resynct, NICHT explizit DPMS einschaltet)
  #
  # KEINE listener-blocks mehr — sonst doppeltes Idle-Timing parallel zu
  # noctalia (würde Lock-Surface evtl. doppelt anfordern). KEIN lock_cmd —
  # noctalia hört dbus "Lock"-Signal selbst und braucht keinen externen
  # Spawn-Helfer (siehe noctalia src/dbus/logind/logind_service.cpp:74).
  services.hypridle = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = {
      general = {
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };
    };
  };
}
