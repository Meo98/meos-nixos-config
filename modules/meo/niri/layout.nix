# Spalten-Layout, Overview und Animationen.
#
# Die Fokusring-Farben spiegeln die bisherige Hyprland-Border
# (modules/upstream/home/hyprland/hyprland.nix:82-83): Gradient base08 -> base0C
# bei 45 Grad fuer aktiv, base01 fuer inaktiv. Damit bleibt der visuelle
# Wiedererkennungswert erhalten und die Farben folgen weiter Stylix.
{config, ...}: let
  c = config.lib.stylix.colors.withHashtag;
in {
  wayland.windowManager.niri.settings = {
    layout = {
      gaps = 8;

      # "never": die fokussierte Spalte wird nicht automatisch zentriert.
      # Beim Einstieg ins scrollable tiling ist ein stabiler Viewport leichter
      # zu lesen als einer, der bei jedem Fokuswechsel nachrueckt.
      # Wenn sich das nach ein paar Tagen falsch anfuehlt: "always" probieren.
      center-focused-column = "never";

      # Mod+R zykliert vorwaerts, Mod+Shift+R rueckwaerts.
      #
      # 0.75 und 0.8 sind bewusst dabei: auf dem eDP (1600 logische px) bleibt
      # damit ein 400 bzw. 320 px breiter Streifen der Nachbarspalte sichtbar.
      # Das ist der Punkt am Scroll-Layout — man sieht, dass rechts noch etwas
      # kommt, statt eine Spalte fuer den ganzen Schirm zu halten.
      #
      # "proportion" rechnet die gaps schon mit ein: vier Fenster mit 0.25
      # passen exakt nebeneinander, unabhaengig vom gaps-Wert oben.
      preset-column-widths._children = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
        {proportion = 0.75;}
        {proportion = 0.8;}
      ];

      default-column-width.proportion = 0.5;

      focus-ring = {
        width = 2;
        active-gradient._props = {
          from = c.base08;
          to = c.base0C;
          angle = 45;
        };
        inactive-color = c.base01;
      };

      # Fokusring statt zusaetzlichem Rahmen — sonst hat jedes Fenster zwei.
      border.off = {};
    };

    # Mod+Tab. Ersetzt den quickshell-Overview-Daemon (qs -c overview), der
    # bisher per exec-once mitlief.
    overview.zoom = 0.5;

    animations.slowdown = 1.0;
  };
}
