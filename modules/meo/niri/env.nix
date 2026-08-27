# Session-Umgebung. Portiert aus modules/upstream/home/hyprland/env.nix,
# aber bewusst reduziert:
#   - XDG_CURRENT_DESKTOP / XDG_SESSION_DESKTOP setzt niri selbst auf "niri";
#     die Hyprland-Werte wuerden Apps in die Irre fuehren.
#   - GDK_SCALE / QT_SCALE_FACTOR entfallen: niri liefert per-Output-Fractional-
#     Scaling ueber wp-fractional-scale, globale Skalenfaktoren wuerden das
#     doppelt anwenden.
#   - NIXPKGS_ALLOW_UNFREE gehoert nicht in eine Session-Umgebung.
{pkgs, ...}: {
  wayland.windowManager.niri.settings = {
    environment = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      CLUTTER_BACKEND = "wayland";
      GDK_BACKEND = "wayland,x11";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "x11";

      # Wie in env.nix: Kinder der Session erben diese Werte, sonst greift
      # noch das alte EDITOR aus dem Profil.
      EDITOR = "nvim";
      TERMINAL = "ghostty";
      XDG_TERMINAL_EMULATOR = "ghostty";
    };

    # XWayland laeuft in niri als eigener Prozess. Das HM-Modul installiert das
    # Paket ueber xwaylandSatellitePackage; hier wird nur der Pfad verdrahtet,
    # damit niri es bei Bedarf selbst startet.
    xwayland-satellite.path = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
  };
}
