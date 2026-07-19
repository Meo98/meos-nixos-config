{
  pkgs,
  config,
  ...
}: let
  # MODIFIED 2026-07-18: Resume-Recovery gegen den eingefrorenen Lockscreen.
  # Beobachtetes Muster (17.07. + 18.07., jeweils Hard-Reboot noetig):
  # Suspend mit gesperrtem noctalia-Lockscreen -> beim Resume i915 GPU-Reset
  # ("guilty-context-reset") -> noctalias EGL-Recovery scheitert und spammt
  # "EGL error 0x3006" (EGL_BAD_CONTEXT) endlos -> Lockscreen rendert nie
  # wieder. Upstream-Fix in v5.0.0-beta.3 (flake.nix), das hier ist das
  # Safety-Net: Wedge erkennen -> noctalia neu starten -> Session neu locken
  # (braucht misc:allow_session_lock_restore=true in hyprland.nix).
  #
  # MODIFIED 2026-07-19: zweite Wedge-Variante beobachtet (Resume nach
  # Nacht-Suspend): KEIN GPU-Reset, KEIN EGL-Spam, stattdessen haengt
  # noctalias Wayland-Mainloop minutenlang ("surface configure resize took
  # 140516ms" / "wl_display_dispatch_pending took 140516ms") und der
  # Lockscreen bleibt schwarz. Log-Grep allein erkennt das nicht ->
  # zusaetzlich aktiver Responsiveness-Probe via `noctalia msg status`
  # (laeuft ueber die Mainloop; haengt sie, laeuft der timeout ab).
  # Pfad ueber /etc/profiles: zeigt immer auf die aktive HM-Generation,
  # Version passt damit immer zur laufenden Instanz.
  noctaliaBin = "/etc/profiles/per-user/${config.home.username}/bin/noctalia";
  resumeRecovery = pkgs.writeShellApplication {
    name = "hypridle-resume-recovery";
    runtimeInputs = [pkgs.systemd pkgs.gnugrep pkgs.coreutils pkgs.util-linux];
    # hyprctl absichtlich NICHT in runtimeInputs: kommt aus dem Service-PATH
    # (overrides.conf), damit die Version zum laufenden Hyprland passt.
    text = ''
      # Bei schnellen Suspend-Zyklen (Deckel auf/zu) nicht doppelt laufen,
      # sonst restarten zwei Instanzen noctalia gleichzeitig.
      exec 9>"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypridle-resume-recovery.lock"
      flock -n 9 || exit 0

      hyprctl dispatch dpms on

      # Beide Wedge-Signaturen 45s lang pruefen: Der EGL-Spam beginnt 2-15s
      # nach Resume; der Mainloop-Haenger braucht 2 fehlgeschlagene Probes
      # in Folge (~13s unresponsive), damit kurzes Resume-Housekeeping
      # keinen falschen Restart ausloest.
      wedged=""
      fails=0
      for _ in $(seq 1 9); do
        sleep 5
        if journalctl --user -u noctalia.service --since "-7 seconds" -q \
             --grep "EGL error 0x3006" | grep -q .; then
          wedged="egl-bad-context"
          break
        fi
        if [ -x "${noctaliaBin}" ] \
           && ! timeout 4 "${noctaliaBin}" msg status >/dev/null 2>&1; then
          fails=$((fails + 1))
          if [ "$fails" -ge 2 ]; then
            wedged="mainloop-unresponsive"
            break
          fi
        else
          fails=0
        fi
      done

      if [ -n "$wedged" ]; then
        echo "noctalia wedged ($wedged), restarting" >&2
        systemctl --user restart noctalia.service
        sleep 2
        loginctl lock-session
      fi
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
