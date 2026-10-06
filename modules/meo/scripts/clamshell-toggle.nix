# Clamshell-Modus: Deckel zu, Maschine laeuft weiter.
#
# ADDED 2026-10-06. Gegenstueck zu der Entscheidung vom selben Tag, dass
# Zuklappen jetzt IMMER suspendiert (services.logind.lidSwitchDocked =
# "suspend" in beiden hosts/*/default.nix). Vorher ergab sich das Clamshell-
# Verhalten als Nebenwirkung des systemd-Defaults "docked -> ignore" — es war
# also immer an und liess sich nicht abschalten. Jetzt ist es umgekehrt: aus
# per Default, an per Taste. Das ist die Richtung, die der Normalfall gewinnt.
#
# MECHANIK: logind laesst sich seinen Lid-Handler per Inhibitor aus der Hand
# nehmen, das ist ausdruecklich vorgesehen (man 5 logind.conf: "A different
# application may disable logind's handling of ... the lid switch by taking a
# low-level inhibitor lock"). Ein normaler User darf das, --mode=block
# eingeschlossen (am 2026-10-06 auf meo-work verifiziert).
#
# Der Inhibitor laeuft als transiente systemd-User-Unit statt als nacktem
# Hintergrundprozess. Damit ist der Zustand abfragbar (systemctl --user
# is-active), ueberlebt das Schliessen des Terminals, in dem er gestartet
# wurde, und haengt an der Session statt an einer PID-Datei, die nach einem
# Absturz luegt.
{
  pkgs,
  # Darf das INTERNE Panel abgeschaltet werden, waehrend der Deckel zu ist?
  # Kommt aus clamshellPanelOff in hosts/<host>/variables.nix. Auf meo ist das
  # FALSE, weil `niri msg output ... off` ein DPMS-Off ist und die i915-Pipe
  # des OLED wedged (derselbe Grund wie bei dmsScreenOff; nur ein Reboot holt
  # den Schirm zurueck). Clamshell funktioniert dort trotzdem, der interne
  # Schirm leuchtet nur unter dem geschlossenen Deckel weiter.
  panelOff ? false,
}:
pkgs.writeShellApplication {
  name = "clamshell-toggle";
  runtimeInputs = with pkgs; [systemd niri jq libnotify coreutils];
  text = ''
    PANEL_OFF=${
      if panelOff
      then "1"
      else "0"
    }
    UNIT=clamshell-inhibit

    note() {
      notify-send -i "$1" "$2" "$3" 2>/dev/null || true
    }

    # `niri msg --json outputs` liefert ein OBJEKT, das nach Connector-Namen
    # geschluesselt ist (DP-6, DP-7, eDP-1 ...), keine Liste. Daher keys[] und
    # nicht .[].name. Die internen Panels sind die eDP*-Connector; das gilt auf
    # beiden Hosts (meo: eDP-1, meo-work: eDP-1).
    internal_outputs() {
      niri msg --json outputs | jq -r 'keys[] | select(startswith("eDP"))'
    }

    panels() {
      [ "$PANEL_OFF" = "1" ] || return 0
      while read -r o; do
        niri msg output "$o" "$1" || true
      done < <(internal_outputs)
    }

    if systemctl --user is-active --quiet "$UNIT"; then
      systemctl --user stop "$UNIT"
      panels on
      note display-symbolic "Clamshell aus" \
        "Zuklappen legt die Maschine wieder schlafen."
    else
      # ACHTUNG BEIM NACHPRUEFEN: systemd-run kehrt sofort zurueck, der
      # Inhibitor-Lock steht aber erst Sekundenbruchteile spaeter. Wer direkt
      # danach `systemd-inhibit --list` aufruft, sieht nichts und haelt das
      # Script faelschlich fuer kaputt (genau so beim Bauen passiert,
      # 2026-10-06). Praktisch irrelevant: zwischen Tastendruck und
      # zugeklapptem Deckel liegt mehr als das.
      systemd-run --user --quiet --unit="$UNIT" \
        --description="Clamshell: logind-Lid-Handler ausgehaengt" \
        systemd-inhibit --what=handle-lid-switch --mode=block \
        --why="Clamshell-Modus" sleep infinity
      panels off
      note video-display-symbolic "Clamshell an" \
        "Deckel zu = Maschine laeuft weiter. Gilt bis zum naechsten Druck."
    fi
  '';
}
