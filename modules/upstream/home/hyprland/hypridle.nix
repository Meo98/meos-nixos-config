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
  # Nacht-Suspend): KEIN GPU-Reset, KEIN EGL-Spam, stattdessen haengt der
  # Wayland-Mainloop minutenlang und der Bildschirm bleibt eingefroren.
  #
  # MODIFIED 2026-08-25: Komplette Neufassung nach Journal-Forensik eines
  # weiteren Freezes (Resume 11:34:48 sauber -> danach 2 Min Totenstille von
  # Hyprland UND noctalia -> User musste per Strg+Alt+Entf rebooten, sichtbar
  # als "systemd[1]: Received SIGINT"). Die alte Fassung hat NIE gegriffen
  # (Bilanz ueber alle Boots: 98 Resumes, 73 Script-Laeufe, 0 erkannte Wedges),
  # aus zwei Konstruktionsfehlern:
  #   1. `hyprctl dispatch dpms on` lief UNGETIMEOUTET als erste Zeile. Ist
  #      der Compositor-Mainloop tot, blockiert genau dieser Aufruf -> die
  #      Probe-Schleife wurde im Ernstfall nie erreicht.
  #   2. Geprobt/neugestartet wurde nur noctalia (Wayland-CLIENT). Der heutige
  #      Freeze war aber HYPRLAND selbst (der Compositor) -> einen Client neu
  #      zu starten heilt einen toten Compositor nicht.
  # Neu: (a) alle Aufrufe timeout-gesichert; (b) ESKALATION — zuerst Hyprlands
  # eigene IPC pruefen (laeuft ueber seinen Event-Loop). Antwortet Hyprland
  # 3x in Folge (~15s) nicht, ist der Compositor wedged -> Session hart neu
  # starten (SIGKILL an Hyprland; sddm faengt das ab und zeigt den Greeter,
  # offene Fenster gehen dabei verloren — bewusst gewaehlt gegen den Freeze).
  # Lebt Hyprland, haengt aber nur noctalia (EGL-Spam ODER Client-Mainloop),
  # bleibt es bei der leichten Shell-Only-Rettung wie zuvor.
  # Pfad ueber /etc/profiles: zeigt immer auf die aktive HM-Generation.
  noctaliaBin = "/etc/profiles/per-user/${config.home.username}/bin/noctalia";
  resumeRecovery = pkgs.writeShellApplication {
    name = "hypridle-resume-recovery";
    runtimeInputs = [pkgs.systemd pkgs.gnugrep pkgs.coreutils pkgs.util-linux pkgs.procps];
    # hyprctl absichtlich NICHT in runtimeInputs: kommt aus dem Service-PATH
    # (overrides.conf), damit die Version zum laufenden Hyprland passt.
    text = ''
      # Bei schnellen Suspend-Zyklen (Deckel auf/zu) nicht doppelt laufen.
      exec 9>"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypridle-resume-recovery.lock"
      flock -n 9 || exit 0

      # Displays aufwecken — jetzt timeout-gesichert, damit dieser Aufruf an
      # einem toten Compositor NICHT mehr die ganze Recovery blockiert.
      timeout 4 hyprctl dispatch dpms on >/dev/null 2>&1 || true

      # Bis zu 60s lang beobachten. "session" = Compositor tot -> harter
      # Session-Neustart. "shell" = nur noctalia haengt -> Shell-Neustart.
      comp_fails=0
      shell_fails=0
      action=""
      for _ in $(seq 1 12); do
        sleep 5

        # (a) Schnellstes Signal: EGL-BAD-CONTEXT-Spam von noctalia (07-18er
        # Variante). Compositor lebt dabei -> Shell-Rettung genuegt.
        if journalctl --user -u noctalia.service --since "-7 seconds" -q \
             --grep "EGL error 0x3006" | grep -q .; then
          action="shell"
          break
        fi

        # (b) Compositor-Responsiveness: hyprctl geht durch Hyprlands
        # Event-Loop. Haengt der Loop, laeuft der timeout ab. 3 Fehlschlaege
        # in Folge (~15s) => wedged, damit kurzes Resume-Housekeeping keinen
        # Fehl-Kill einer gesunden Session ausloest.
        if ! timeout 4 hyprctl version >/dev/null 2>&1; then
          comp_fails=$((comp_fails + 1))
          if [ "$comp_fails" -ge 3 ]; then
            action="session"
            break
          fi
          # Toter Compositor macht die noctalia-Probe unten sinnlos
          # (der Client haengt dann zwangslaeufig mit) -> ueberspringen.
          continue
        else
          comp_fails=0
        fi

        # (c) Shell-Responsiveness — nur aussagekraeftig, solange der
        # Compositor lebt. `noctalia msg status` laeuft ueber dessen Mainloop.
        if [ -x "${noctaliaBin}" ] \
           && ! timeout 4 "${noctaliaBin}" msg status >/dev/null 2>&1; then
          shell_fails=$((shell_fails + 1))
          if [ "$shell_fails" -ge 2 ]; then
            action="shell"
            break
          fi
        else
          shell_fails=0
        fi
      done

      case "$action" in
        session)
          echo "compositor (Hyprland) unresponsive nach Resume — Session-Neustart" >&2
          # SIGTERM wird von einem gewedgten Mainloop (signalfd) meist nicht
          # mehr verarbeitet -> nach kurzer Gnadenfrist hart per SIGKILL.
          pkill -TERM -x Hyprland || true
          sleep 3
          pkill -KILL -x Hyprland || true
          ;;
        shell)
          echo "noctalia (Shell) wedged nach Resume — Shell-Neustart" >&2
          systemctl --user restart noctalia.service
          sleep 2
          loginctl lock-session || true
          ;;
      esac
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
