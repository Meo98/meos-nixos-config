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
    # base16Scheme = {
    #   base00 = "282936";
    #   base01 = "3a3c4e";
    #   base02 = "4d4f68";
    #   base03 = "626483";
    #   base04 = "62d6e8";
    #   base05 = "e9e9f4";
    #   base06 = "f1f2f8";
    #   base07 = "f7f7fb";
    #   base08 = "ea51b2";
    #   base09 = "b45bcf";
    #   base0A = "00f769";
    #   base0B = "ebff87";
    #   base0C = "a1efe4";
    #   base0D = "62d6e8";
    #   base0E = "b45bcf";
    #   base0F = "00f769";
    # };
    polarity = "dark";
    opacity.terminal = 1.0;
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrains Mono";
      };
      # MODIFIED 2026-08-04: Montserrat -> Noto. Montserrats breite Metriken
      # sprengten App-Layouts (FreeCAD-Wizard, Bambu-Dialoge liefen rechts aus
      # dem Screen) — Qt/GTK-Apps dimensionieren Dialoge fuer Noto/DejaVu.
      # Per-App-Fontconfig-Workarounds (bambu.nix, freecadFontFix) damit obsolet
      # und entfernt. Montserrat bleibt via fonts.packages unten fuer Dokumente
      # installiert, ist nur nicht mehr UI-Standard.
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
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
