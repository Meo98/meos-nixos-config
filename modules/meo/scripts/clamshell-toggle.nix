# Clamshell-Modus: Deckel zu, Maschine laeuft weiter.
#
# ADDED 2026-10-06. Gegenstueck zu der Entscheidung vom selben Tag, dass
# Zuklappen jetzt IMMER suspendiert (services.logind.lidSwitchDocked =
# "suspend" in beiden hosts/*/default.nix). Vorher ergab sich das Clamshell-
# Verhalten als Nebenwirkung des systemd-Defaults "docked -> ignore" — es war
# also immer an und liess sich nicht abschalten. Jetzt ist es umgekehrt: aus
# per Default, an per Taste (Mod+Alt+D).
#
# MECHANIK: logind laesst sich seinen Lid-Handler per Inhibitor aus der Hand
# nehmen, das ist ausdruecklich vorgesehen (man 5 logind.conf: "A different
# application may disable logind's handling of ... the lid switch by taking a
# low-level inhibitor lock"). Ein normaler User darf das, --mode=block
# eingeschlossen (am 2026-10-06 auf meo-work verifiziert).
#
# Beide Hintergrundprozesse laufen als transiente systemd-User-Units statt als
# nackten Hintergrundprozessen. Damit ist der Zustand abfragbar (systemctl
# --user is-active), ueberlebt das Schliessen des Terminals, in dem er
# gestartet wurde, und haengt an der Session statt an einer PID-Datei, die
# nach einem Absturz luegt.
#
# ERWEITERT 2026-10-07 um die Bildschirm-Abschaltung nach Untaetigkeit. Der
# Watcher ist swayidle auf ext-idle-notify-v1; dass niri das Protokoll
# bedient, ist nicht nur Dokumentation, sondern am 2026-10-07 auf meo-work
# gegen den laufenden Compositor gemessen.
{
  pkgs,
  # Darf das INTERNE Panel abgeschaltet werden, waehrend der Deckel zu ist?
  # Kommt aus clamshellPanelOff in hosts/<host>/variables.nix. Auf meo ist das
  # FALSE, weil `niri msg output ... off` ein DPMS-Off ist und die i915-Pipe
  # des OLED wedged (derselbe Grund wie bei dmsScreenOff; nur ein Reboot holt
  # den Schirm zurueck). Clamshell funktioniert dort trotzdem, der interne
  # Schirm leuchtet nur unter dem geschlossenen Deckel weiter.
  panelOff ? false,
  # Nach wie vielen Sekunden Untaetigkeit die EXTERNEN Schirme ausgehen.
  # Einziger Stellknopf dafuer — bewusst hier und nicht in variables.nix, weil
  # der Wert nichts Hostspezifisches beschreibt (keine Hardware-Eigenschaft,
  # nur Geschmack).
  #
  # 180 statt des DMS-Idle-Timers von 600 (modules/meo/dms/settings.nix:41):
  # bei zugeklapptem Deckel ist "weg" der Normalfall, nicht "liest gerade".
  # Die beiden laufen nebeneinander und stoeren sich nicht — DMS sperrt
  # zusaetzlich bei 600 s und schaltet (nur meo-work) selbst nochmal ab.
  # Doppeltes Abschalten ist idempotent.
  idleSecs ? 180,
}: let
  # Eigene Derivation statt Inline-Pipeline, zwei Gruende — siehe Kopf von
  # clamshell-screens.nix. Der hier wichtige: swayidle laeuft in einer
  # transienten Unit, deren PATH NICHT der des home-manager-Profils ist. Ein
  # Aufruf per Namen ginge dort ins Leere, der Store-Pfad nicht.
  screens = import ./clamshell-screens.nix {inherit pkgs;};
in
  pkgs.writeShellApplication {
    name = "clamshell-toggle";
    runtimeInputs = with pkgs; [systemd niri jq libnotify coreutils swayidle];
    text = ''
      PANEL_OFF=${
        if panelOff
        then "1"
        else "0"
      }
      UNIT=clamshell-inhibit
      IDLE_UNIT=clamshell-idle

      note() {
        notify-send -i "$1" "$2" "$3" 2>/dev/null || true
      }

      # `niri msg --json outputs` liefert ein OBJEKT, das nach Connector-Namen
      # geschluesselt ist (DP-6, DP-7, eDP-1 ...), keine Liste. Daher keys[]
      # und nicht .[].name. Die internen Panels sind die eDP*-Connector; das
      # gilt auf beiden Hosts (meo: eDP-1, meo-work: eDP-1).
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
        systemctl --user stop "$IDLE_UNIT" 2>/dev/null || true

        # Beide wieder an, BEVOR die Meldung kommt: der Watcher koennte die
        # externen Schirme gerade abgeschaltet haben, und ein Clamshell-Aus
        # mit schwarzen Monitoren waere die unfreundlichste mogliche Antwort.
        ${screens}/bin/clamshell-screens on
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

        # -w laesst swayidle auf das Ende des Kommandos warten, sonst koennen
        # sich off und on bei schnellem Wechsel ueberholen.
        systemd-run --user --quiet --unit="$IDLE_UNIT" \
          --description="Clamshell: externe Schirme nach Untaetigkeit aus" \
          swayidle -w \
          timeout ${toString idleSecs} "${screens}/bin/clamshell-screens off" \
          resume "${screens}/bin/clamshell-screens on"

        panels off

        note video-display-symbolic "Clamshell an" \
          "Deckel zu = laeuft weiter. Externe Schirme nach ${toString (idleSecs / 60)} Min aus."
      fi
    '';
  }
