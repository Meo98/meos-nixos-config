{ config, pkgs, ... }:
# --- LOCK VOR SUSPEND (2026-08-27 meo, 2026-08-31 meo-work) ---
# Frueher sperrte hypridle die Session vor dem Suspend (before_sleep_cmd =
# "loginctl lock-session", modules/upstream/home/hyprland/hypridle.nix).
# hypridle haengt aber an systemdTarget = "hyprland-session.target" und
# startet unter niri gar nicht. Ohne diesen Hook wuerde lidSwitch = "suspend"
# die Maschine UNGESPERRT schlafen legen; Noctalias eigener Idle-Lock ist ein
# 600-s-Timer und deckt keinen Suspend-Hook ab.
#
# Betrifft beide niri-Hosts (meo seit der Migration am 27.08.2026, meo-work
# seit der Migration am 31.08.2026) — deshalb geteiltes Modul statt zweier
# Kopien, die beim naechsten Mal wieder auseinanderlaufen wuerden. Importiert
# hostlokal aus hosts/meo/default.nix UND hosts/meo-work/default.nix, NICHT
# aus modules/meo/default.nix (das ist ein home-manager-Modul, diese Unit
# eine NixOS-System-Unit).
#
# Bewusst SYSTEM-Ebene und compositor-neutral: greift unter niri UND unter
# Hyprland (Rollback-Session, auf beiden Hosts waehlbar). Unter Hyprland
# sperrt hypridle zusaetzlich — doppeltes Sperren ist idempotent und harmlos,
# das ist KEIN Grund, den Hook wieder "wegzuoptimieren". `lock-sessions`
# (Plural) statt `lock-session`, weil hier root ohne eigene Session laeuft.
#
# Das kurze sleep hat denselben Grund wie beim Bind Mod+Alt+L
# (modules/meo/niri/binds-apps.nix): der Compositor braucht einen Moment, um
# das Lock-Surface zu committen, bevor die Maschine runtergeht.
{
  systemd.services.lock-before-sleep = {
    description = "Lock all sessions before suspend/hibernate";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      # MODIFIED 2026-08-27: TimeoutStartSec ergaenzt. `loginctl lock-sessions`
      # kehrt normalerweise sofort zurueck, haengt aber am System-Bus. Ist der
      # wedged, wuerde der systemd-Default (90s) den Suspend so lange blockieren,
      # bevor `|| true` ueberhaupt erreicht wird — beim Zuklappen also 1.5 Minuten
      # mit laufender Maschine im Rucksack. 5s reichen fuer den Normalfall.
      TimeoutStartSec = 5;
      ExecStart = pkgs.writeShellScript "lock-before-sleep" ''
        ${config.systemd.package}/bin/loginctl lock-sessions || true
        ${pkgs.coreutils}/bin/sleep 0.5
      '';
    };
  };
}
