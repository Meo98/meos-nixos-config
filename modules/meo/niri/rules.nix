# Benannter Workspace + Fensterregeln.
#
# Nur eine Teilmenge der 400+ Zeilen aus modules/upstream/home/hyprland/
# windowrules.nix wird portiert. niris window-rule kann app-id/title matchen und
# open-floating, open-maximized, open-on-workspace, Geometrie, Opacity sowie
# block-out-from setzen — aber nicht das volle Hyprland-Vokabular. Der Rest
# wandert nach Bedarf nach, wenn im Alltag etwas auffaellt.
#
# REIHENFOLGE IST BEDEUTSAM: bei niri gewinnt die zuletzt passende Regel.
# Deshalb steht die generische Geometrie-Regel zuerst und die spezifischen
# danach. Alle Regeln muessen in dieser einen Datei bleiben.
{...}: {
  wayland.windowManager.niri.settings._children = [
    # Der Workspace, auf den niri-term-toggle (Mod+Shift+T) springt.
    {workspace._args = ["term"];}

    # Generische Optik fuer alle Fenster.
    {
      window-rule._children = [
        {geometry-corner-radius = 8;}
        {clip-to-geometry = true;}
      ];
    }

    # Dropdown-Terminal-Ersatz: eigene app-id, liegt fest auf "term".
    #
    # kitty statt ghostty (Ruling 4 aus dem Task-Briefing): ghostty laeuft
    # mit gtk-single-instance = true, ein zweiter Aufruf delegiert daher nur
    # an die schon laufende Instanz und wendet --class nie an — die Regel
    # haette nie gegriffen. kitty ist ohnehin fest installiert und respektiert
    # --class; kitty-dropterm war schon unter pyprland die Scratchpad-Klasse.
    {
      window-rule._children = [
        {match._props.app-id = "^kitty-dropterm$";}
        {open-on-workspace = "term";}
        {open-maximized = true;}
      ];
    }

    # Dashboard-Spalte (modules/meo/niri/dashboard.nix). Breite = 1/12, damit
    # sie bei 5/6 Arbeitsbreite exakt in die Luecke links passt: die
    # fokussierte Spalte ist zentriert, links und rechts bleiben (1 - 5/6)/2
    # = 1/12 uebrig. Waere sie breiter, ragte ihr linker Teil aus dem Bild.
    #
    # Kein open-focused false: move-column-to-index wirkt nur auf die
    # FOKUSSIERTE Spalte. Geht das Dashboard normal fokussiert auf, braucht
    # der Daemon zwei Aufrufe (schieben, Fokus zurueck) statt drei.
    #
    # Auch hier kitty statt ghostty — dieselbe gtk-single-instance-Falle wie
    # bei kitty-dropterm oben.
    {
      window-rule._children = [
        {match._props.app-id = "^niri-dashboard$";}
        {default-column-width.proportion = 0.08333;}
      ];
    }

    # Kleine Dialoge sollen nicht das Spaltenlayout aufreissen.
    {
      window-rule._children = [
        {match._props.app-id = "^org.pulseaudio.pavucontrol$";}
        {match._props.app-id = "^nm-connection-editor$";}
        {match._props.app-id = "^blueman-manager$";}
        {match._props.app-id = "^org.gnome.Calculator$";}
        {open-floating = true;}
      ];
    }

    # Picture-in-Picture unten rechts, schwebend.
    {
      window-rule._children = [
        {match._props.title = "^Picture-in-Picture$";}
        {open-floating = true;}
        {
          default-floating-position._props = {
            x = 32;
            y = 32;
            relative-to = "bottom-right";
          };
        }
      ];
    }

    # Passwortmanager nicht in Screenshares/Aufnahmen durchreichen.
    {
      window-rule._children = [
        {match._props.app-id = "^1Password$";}
        {block-out-from = "screen-capture";}
      ];
    }
  ];
}
