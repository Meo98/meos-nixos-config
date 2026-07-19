{pkgs, ...}: let
  # MODIFIED 2026-07-18: Resume-Recovery gegen den eingefrorenen Lockscreen.
  # Beobachtetes Muster (17.07. + 18.07., jeweils Hard-Reboot noetig):
  # Suspend mit gesperrtem noctalia-Lockscreen -> beim Resume i915 GPU-Reset
  # ("guilty-context-reset") -> noctalias EGL-Recovery scheitert und spammt
  # "EGL error 0x3006" (EGL_BAD_CONTEXT) endlos -> Lockscreen rendert nie
  # wieder. Upstream-Fix in v5.0.0-beta.3 (flake.nix), das hier ist das
  # Safety-Net: Wedge erkennen -> noctalia neu starten -> Session neu locken
  # (braucht misc:allow_session_lock_restore=true in hyprland.nix).
  resumeRecovery = pkgs.writeShellApplication {
    name = "hypridle-resume-recovery";
    runtimeInputs = [pkgs.systemd pkgs.gnugrep pkgs.coreutils];
    # hyprctl absichtlich NICHT in runtimeInputs: kommt aus dem Service-PATH
    # (overrides.conf), damit die Version zum laufenden Hyprland passt.
    text = ''
      hyprctl dispatch dpms on
      # Der EGL-Spam beginnt 2-15s nach Resume (Render-Thread haengt erst
      # noch in eglMakeCurrent). 9x5s Polling deckt das Fenster ab.
      for _ in $(seq 1 9); do
        sleep 5
        if journalctl --user -u noctalia.service --since "-7 seconds" -q \
             --grep "EGL error 0x3006" | grep -q .; then
          systemctl --user restart noctalia.service
          sleep 2
          loginctl lock-session
          break
        fi
      done
    '';
  };
in {
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
        # MODIFIED 2026-07-18: dpms on + EGL-Wedge-Detection (siehe oben)
        after_sleep_cmd = "${resumeRecovery}/bin/hypridle-resume-recovery";
        ignore_dbus_inhibit = false;
      };
    };
  };
}
