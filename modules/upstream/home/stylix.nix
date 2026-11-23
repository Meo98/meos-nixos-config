{
  lib,
  options,
  ...
}: {
  stylix.targets =
    {
      # Avoid fetching GNOME Shell sources on non-GNOME systems (breaks on some remotes)
      gnome.enable = false;
      waybar.enable = false;
      rofi.enable = false;
      hyprland.enable = false;
      hyprlock.enable = false;
      ghostty.enable = false;
      qt = {
        enable = true;
        platform = "qtct";
      };
    }
    # MODIFIED 2026-11-23: home-manager hat programs.wayprompt entfernt
    # (Paket aus nixpkgs geflogen), Stylix faerbt es aber noch ein ->
    # "option definition `programs.wayprompt' no longer has any effect".
    # Nur abschalten, solange Stylix das Target noch kennt; sobald Stylix
    # es ebenfalls loescht, faellt diese Zeile von selbst weg (kein neuer
    # "option does not exist"-Fehler).
    // lib.optionalAttrs (options.stylix.targets ? wayprompt) {
      wayprompt.enable = false;
    };
}
