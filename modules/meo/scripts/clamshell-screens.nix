# Schaltet die EXTERNEN Schirme an oder aus. Helfer fuer clamshell-toggle.nix.
#
# ADDED 2026-10-07.
#
# WARUM EINE EIGENE DERIVATION UND KEIN INLINE-EINZEILER: der Aufrufer ist
# swayidle, und swayidle bekommt sein Kommando als EINEN String, den es per
# `sh -c` ausfuehrt. Eine Pipeline mit jq-Filter und verschachtelten
# Anfuehrungszeichen dort hineinzuquoten — durch einen Nix-''-String UND eine
# systemd-run-Kommandozeile hindurch — ist genau die Sorte Code, die beim
# naechsten Anfassen bricht. Als eigenes Binary ist es ein Wort.
#
# Der zweite Grund ist der Store-Pfad: clamshell-toggle startet swayidle in
# einer transienten systemd-User-Unit, und deren PATH ist NICHT der des
# home-manager-Profils. Ein Aufruf per Namen ginge dort ins Leere; als eigene
# Derivation laesst sich der absolute Pfad zur Bauzeit einsetzen.
#
# BEWUSST NUR DIE EXTERNEN: die internen eDP-Panels fasst dieses Script nie
# an. Deren Abschaltung haengt an clamshellPanelOff (hosts/*/variables.nix),
# weil `output off` auf meo die i915-Pipe des OLED wedged — siehe
# clamshell-toggle.nix. Durch die Trennung ist DIESES Script auf beiden Hosts
# bedingungslos sicher.
{pkgs}:
pkgs.writeShellApplication {
  name = "clamshell-screens";
  runtimeInputs = with pkgs; [niri jq];
  text = ''
    action=''${1:-}
    case "$action" in
      on | off) ;;
      *)
        echo "usage: clamshell-screens on|off" >&2
        exit 2
        ;;
    esac

    # `niri msg --json outputs` liefert ein OBJEKT, geschluesselt nach
    # Connector-Namen (DP-6, DP-7, eDP-1 ...), keine Liste — daher keys[].
    niri msg --json outputs \
      | jq -r 'keys[] | select(startswith("eDP") | not)' \
      | while read -r o; do
        niri msg output "$o" "$action" || true
      done
  '';
}
