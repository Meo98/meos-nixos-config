{
  pkgs,
  host,
  ...
}: let
  inherit (import ../../../hosts/${host}/variables.nix) stylixImage;
in {
  # Styling Options
  stylix = {
    enable = true;
    image = stylixImage;
    # ── theme-picker verwaltet die Zeile zwischen den Markern ──────────────
    # Steht dort eine `base16Scheme = …;`-Zeile, gilt dieses feste Schema;
    # ist der Bereich leer, generiert Stylix die Palette aus dem Wallpaper
    # (stylix.image). Komfortabel umschalten via `theme-picker` (fzf-TUI,
    # modules/meo/scripts/theme-picker.nix). Nicht von Hand editieren.
    # THEME_PICKER_SCHEME_BEGIN
    # theme-picker: ayu-mirage
    base16Scheme = {
      base00 = "1f2430";
      base01 = "242936";
      base02 = "323844";
      base03 = "4a5059";
      base04 = "707a8c";
      base05 = "cccac2";
      base06 = "d9d7ce";
      base07 = "f3f4f5";
      base08 = "f28779";
      base09 = "ffad66";
      base0A = "ffd173";
      base0B = "d5ff80";
      base0C = "95e6cb";
      base0D = "73d0ff";
      base0E = "d4bfff";
      base0F = "f27983";
    };
    # THEME_PICKER_SCHEME_END
    polarity = "dark";
    opacity.terminal = 1.0;
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    fonts = {
      # THEME_PICKER_MONO_BEGIN  (Zeile via `theme-picker` austauschbar)
      monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrains Mono"; };
      # THEME_PICKER_MONO_END
      # MODIFIED 2026-08-04: Montserrat -> Noto. Montserrats breite Metriken
      # sprengten App-Layouts (FreeCAD-Wizard, Bambu-Dialoge liefen rechts aus
      # dem Screen) — Qt/GTK-Apps dimensionieren Dialoge fuer Noto/DejaVu.
      # Per-App-Fontconfig-Workarounds (bambu.nix, freecadFontFix) damit obsolet
      # und entfernt. Montserrat bleibt via fonts.packages unten fuer Dokumente
      # installiert, ist nur nicht mehr UI-Standard.
      # THEME_PICKER_SANS_BEGIN  (Zeile via `theme-picker` austauschbar; nur
      # metrik-sichere Fonts anbieten — breite Fonts sprengen Dialoge, s.o.)
      sansSerif = { package = pkgs.noto-fonts; name = "Noto Sans"; };
      # THEME_PICKER_SANS_END
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      sizes = {
        applications = 12;
        terminal = 15;
        desktop = 11;
        popups = 12;
      };
    };
  };

  # MODIFIED 2026-08-04: Montserrat weiterhin installieren (Dokumente/Design,
  # z.B. Affinity), obwohl es oben nicht mehr System-UI-Font ist.
  fonts.packages = [ pkgs.montserrat ];
}
