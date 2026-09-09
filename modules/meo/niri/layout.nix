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

      # MODIFIED 2026-09-09: "always" -> "never". ACHTUNG, das liest sich wie
      # ein Rueckschritt zum Zustand vor dem 28.08. und ist das Gegenteil.
      #
      # "always" zentriert AUCH die erste und die letzte Spalte. Dort gibt es
      # aussen aber keinen Nachbarn, also blieb dort (1 - Breite)/2 des
      # Schirms schlicht leer — der Rand, ueber den sich beim Benutzen
      # gestolpert wurde. Und weil Zentrierung symmetrisch wirkt, laesst sich
      # das durch Verbreitern nicht beheben: jeder Zuschlag verkleinert den
      # toten Aussenrand und den Guckstreifen nach innen gleichermassen.
      #
      # Mit "never" klemmt niri die Ansicht an den Enden fest: die erste
      # Spalte sitzt buendig links, die letzte buendig rechts, aussen bleibt
      # nichts leer. Die Zentrierung der MITTLEREN Spalten uebernimmt
      # stattdessen der Daemon aus edge-width.nix per `center-column` — die
      # gewohnte Optik bleibt also, sie kommt nur aus einer anderen Quelle.
      #
      # ABHAENGIGKEIT, DIE MAN KENNEN MUSS: faellt niri-edge-width.service
      # aus, wird gar nichts mehr zentriert (vorher waere nur die
      # Randverbreiterung ausgeblieben). Der Dienst hat deshalb
      # Restart=always.
      center-focused-column = "never";

      # Mod+R zykliert vorwaerts, Mod+Shift+R rueckwaerts.
      #
      # 5/6 ist die Arbeitsbreite: auf dem eDP (1600 logische px) bleibt damit
      # ein ~265 px schmaler Streifen der Nachbarspalte stehen. Genau der Punkt
      # am Scroll-Layout — man sieht, dass rechts noch etwas kommt, ohne dass
      # der Streifen als zweites Fenster mitliest. 3/4 und 4/5 waren am
      # 2026-08-28 kurz zum Vergleich drin und sind wieder raus, weil 5/6
      # gewonnen hat.
      #
      # "proportion" rechnet die gaps schon mit ein: vier Fenster mit 0.25
      # passen exakt nebeneinander, unabhaengig vom gaps-Wert oben.
      preset-column-widths._children = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
        {proportion = 0.83333;}
      ];

      # Neue Fenster starten gleich in der Arbeitsbreite.
      default-column-width.proportion = 0.83333;

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
