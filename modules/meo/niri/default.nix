# niri — scrollable-tiling Wayland compositor.
# Spec: docs/superpowers/specs/2026-08-27-niri-migration-design.md
#
# Home-Manager-Modul. Die System-Seite (programs.niri.enable und
# services.displayManager.defaultSession) liegt bewusst in hosts/meo/default.nix,
# damit meo-work diesen Code zwar im Repo hat, aber nie in seiner Session.
#
# Die Unterdateien schreiben alle in wayland.windowManager.niri.settings; das
# Modulsystem merged Attrsets und konkateniert _children-Listen.
{pkgs, ...}: {
  imports = [
    # weitere Dateien werden in den folgenden Tasks ergaenzt
  ];

  wayland.windowManager.niri = {
    enable = true;
    package = pkgs.niri;
    systemd.enable = true;
    xwaylandSatellitePackage = pkgs.xwayland-satellite;

    # checkConfig ist per Default an (weil package != null) und laesst die
    # generierte KDL in der checkPhase durch `niri validate` laufen. Ein
    # Config-Fehler bricht damit den Build, nicht die Session.
    settings = {
      # Client-Side-Decorations abschalten, wo die App mitspielt.
      prefer-no-csd = {};

      # Gleiche Ablage wie die bisherigen hyprshot-Binds.
      screenshot-path = "~/Pictures/ScreenShots/%Y-%m-%d %H-%M-%S.png";

      # Die Tastenuebersicht nicht bei jedem Login einblenden; sie liegt auf Mod+F1.
      hotkey-overlay.skip-at-startup = {};
    };
  };
}
