# niri — scrollable-tiling Wayland compositor.
# Spec: docs/superpowers/specs/2026-08-27-niri-migration-design.md
#
# Home-Manager-Modul. Die System-Seite (programs.niri.enable und
# services.displayManager.defaultSession) liegt bewusst hostlokal, nicht hier
# oder in modules/upstream/core/packages.nix. Seit der meo-work-Migration
# (2026-08-31) steht sie in BEIDEN hosts/*/default.nix — jeder Host importiert
# sie fuer sich selbst, statt sie zentral zu teilen.
#
# Die Unterdateien schreiben alle in wayland.windowManager.niri.settings; das
# Modulsystem merged Attrsets und konkateniert _children-Listen.
{pkgs, ...}: {
  imports = [
    ./env.nix
    ./input.nix
    ./outputs.nix
    ./layout.nix
    ./binds-nav.nix
    ./binds-apps.nix
    ./rules.nix
    ./startup.nix
    ./hyprland-compat.nix
    ./dashboard.nix
  ];

  # Helper-Scripts, die niri-spezifische Binds brauchen (Task 7,
  # binds-apps.nix). Bewusst hier und nicht in modules/meo/scripts.nix,
  # kolokiert mit dem niri-Feature, das sie braucht — nicht wegen einer
  # Host-Trennung: seit 2026-08-31 importieren beide Hosts dieses Modul.
  #
  # wl-color-picker: Ersatz fuer hyprpicker, das Hyprland-Protokolle braucht.
  # Setzt auf grim/slurp und damit auf zwlr_screencopy_manager_v1, das niri
  # implementiert.
  home.packages = [
    (import ../scripts/keymap-popup.nix {inherit pkgs;})
    (import ../scripts/niri-term-toggle.nix {inherit pkgs;})
    pkgs.wl-color-picker
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
