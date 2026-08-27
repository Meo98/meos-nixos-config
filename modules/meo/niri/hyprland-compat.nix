# Guards fuer Hyprland-spezifische User-Units, die unter niri mitlaufen wuerden.
#
# modules/upstream/home/noctalia.nix definiert hyprland-monitor-hotplug mit
# After/PartOf/WantedBy = graphical-session.target. Dieses Target kommt unter
# niri genauso hoch wie unter Hyprland (niri.service traegt BindsTo darauf,
# siehe modules/meo/niri-gpu-smart.nix). Der Service socat't aber auf Hyprlands
# IPC-Socket: unter niri wuerde er sofort scheitern, per Restart=on-failure
# neu starten und schliesslich im Rate-Limiter als "failed" parken. Seine
# Aufgabe — das Monitor-Layout nach Hotplug wiederherstellen — ist unter niri
# ohnehin ueberfluessig, weil outputs.nix die Outputs deklarativ setzt.
#
# noctalia.nix ist shared mit meo-work und darf nicht angefasst werden, deshalb
# der Guard von hier aus. Er DEAKTIVIERT den Service NICHT: unter Hyprland
# (Rollback-Session) laeuft er unveraendert weiter.
#
# ExecCondition statt "enable = false": systemd ueberspringt eine Unit sauber
# (inactive/dead, KEIN failed), wenn ein ExecCondition-Kommando mit 1..254
# endet. `[ -z "$NIRI_SOCKET" ]` liefert genau das, sobald niri laeuft.
#
# Timing ist abgedeckt: niri importiert NIRI_SOCKET per
# `systemctl --user import-environment` in den User-Manager und WARTET auf den
# Import (src/main.rs: import_environment() -> child.wait()), bevor es systemd
# Ready meldet. Erst danach aktiviert systemd graphical-session.target und
# damit diesen Service.
#
# Merge-Verhalten: home-managers systemd.user.services ist ein Submodul mit
# freeformType attrsOf (attrsOf ...). Service.ExecCondition von hier merged
# also mit Service.ExecStart aus noctalia.nix; kein mkForce noetig, weil kein
# Schluessel doppelt belegt wird.
{pkgs, ...}: {
  systemd.user.services.hyprland-monitor-hotplug.Service.ExecCondition = pkgs.writeShellScript "hotplug-only-without-niri" ''
    [ -z "''${NIRI_SOCKET:-}" ]
  '';
}
