{host, ...}: let
  inherit (import ../../../../hosts/${host}/variables.nix) animChoice;
in {
  # MODIFIED 2026-06-12: hypridle entfernt — Noctalia v5 hat eingebauten idle
  # daemon (idle.behavior.{lock,screen-off}) der lock + DPMS + sleep-inhibit
  # vollständig übernimmt. Parallelbetrieb verursachte race conditions beim
  # DPMS-resume (hypridle's `hyprctl reload` triggerte monitor-scale regression
  # 1.6× → 1.0× → "alles riesig" auf eDP-1). Siehe noctalia.nix settings.
  imports = [
    animChoice
    ./binds.nix
    ./env.nix
    ./exec-once.nix
    ./hyprland.nix
    ./hyprlock.nix
    ./windowrules.nix
  ];
}
