# Navigation, Fenster bewegen, Layout-Manipulation.
#
# Schema laut Spec Abschnitt 7 (Hybrid):
#   - h/l und Pfeil links/rechts wechseln die SPALTE (Achsenwechsel gegenueber
#     Hyprland, wo es Richtungsfokus war)
#   - j/k und Pfeil hoch/runter wechseln das Fenster INNERHALB der Spalte und
#     laufen am Spaltenende auf den WORKSPACE ueber (Workspaces sind in niri
#     vertikal gestapelt)
#   - Ctrl dazu (Mod+Ctrl+hjkl bzw. Pfeile) wechselt den MONITOR
#
#   u/i waren bis 2026-10-06 der Workspace-Wechsel und sind ersatzlos raus;
#   nur Mod+Shift+u/i lebt weiter (ganze Spalte auf Nachbar-Workspace).
#
# DREI ACHSEN, NICHT ZWEI: Spalte -> Workspace -> Monitor. Workspaces gehoeren
# in niri dem Output, nicht dem System; die Nummern in der Bar sind also pro
# Monitor und Mod+1..0 kommt nie vom aktuellen Monitor weg. Details im Block
# "Fokus: Monitor" unten.
#
# Bewusst NICHT uebernommen (kein Gegenstueck im Spalten-Modell): pseudo,
# togglesplit, workspaceopt allfloat, swapwindow hoch/runter.
#
# Mod+Alt+H/L waere die konsequente VI-Variante fuer swap, kollidiert aber mit
# Mod+Alt+L (Lock and Suspend) in binds-apps.nix. Die bisherige Hyprland-Config
# loeste das ueber rohe Keycodes (43/46); die kennt niri nicht. Deshalb liegt
# swap ausschliesslich auf Mod+Alt+Pfeil.
{...}: let
  # Mod+<n> fokussiert Workspace n, Mod+Shift+<n> schiebt die Spalte dorthin.
  # Taste "0" steht wie bisher fuer Workspace 10.
  wsKeys = [
    {
      key = "1";
      ws = 1;
    }
    {
      key = "2";
      ws = 2;
    }
    {
      key = "3";
      ws = 3;
    }
    {
      key = "4";
      ws = 4;
    }
    {
      key = "5";
      ws = 5;
    }
    {
      key = "6";
      ws = 6;
    }
    {
      key = "7";
      ws = 7;
    }
    {
      key = "8";
      ws = 8;
    }
    {
      key = "9";
      ws = 9;
    }
    {
      key = "0";
      ws = 10;
    }
  ];

  focusBinds = builtins.listToAttrs (map (e: {
      name = "Mod+${e.key}";
      value.focus-workspace = e.ws;
    })
    wsKeys);

  moveBinds = builtins.listToAttrs (map (e: {
      name = "Mod+Shift+${e.key}";
      value.move-column-to-workspace = e.ws;
    })
    wsKeys);
in {
  wayland.windowManager.niri.settings.binds =
    focusBinds
    // moveBinds
    // {
      # ---- Fokus: Spalten ----
      # MODIFIED 2026-10-06: focus-column-* -> focus-column-or-monitor-*.
      # Grund siehe Block "Fokus: Monitor" weiter unten. Solange die Spalte
      # einen Nachbarn hat, verhaelt sich das identisch zu vorher; erst AM
      # RAND des Workspace rollt der Fokus auf den Nachbarmonitor ueber,
      # statt stehenzubleiben.
      "Mod+H".focus-column-or-monitor-left = {};
      "Mod+L".focus-column-or-monitor-right = {};
      "Mod+Left".focus-column-or-monitor-left = {};
      "Mod+Right".focus-column-or-monitor-right = {};

      # ---- Fokus: Fenster in der Spalte, dann Workspace ----
      # MODIFIED 2026-10-06, zweiter Durchgang am selben Tag:
      # focus-window-or-MONITOR-* -> focus-window-or-WORKSPACE-*.
      #
      # Der erste Durchgang hatte heute frueh den Monitor als Ueberlaufziel.
      # Das war eine Fehlkonstruktion, und zwar eine, die man nur im Betrieb
      # sieht: die allermeisten Spalten enthalten genau EIN Fenster. Der
      # "or"-Teil griff also praktisch immer sofort, womit Mod+J buchstaeblich
      # dasselbe tat wie Mod+Ctrl+J weiter unten. Zwei Tasten, eine Funktion.
      #
      # Mit dem Workspace als Ueberlaufziel deckt sich die Tastengeometrie
      # jetzt mit der Modellgeometrie: Workspaces sind in niri ein VERTIKALER
      # Stapel pro Monitor, Monitore stehen nebeneinander. Also vertikal ->
      # Workspace, horizontal -> Monitor, Ctrl -> expliziter Monitorsprung.
      # Drei Achsen, drei Tastengruppen, keine Ueberschneidung.
      #
      # ERSETZT Mod+U/I (focus-workspace-down/up), die damit ersatzlos
      # entfallen — sie waren der Grund, warum die vertikale Achse ueberhaupt
      # auf zwei Tastenpaare verteilt lag.
      "Mod+J".focus-window-or-workspace-down = {};
      "Mod+K".focus-window-or-workspace-up = {};
      "Mod+Down".focus-window-or-workspace-down = {};
      "Mod+Up".focus-window-or-workspace-up = {};

      # cooldown-ms daempft das Hi-Res-Scrollrad des Keyball, sonst rauscht ein
      # Wisch durch mehrere Workspaces.
      "Mod+WheelScrollDown" = {
        _props.cooldown-ms = 150;
        focus-workspace-down = {};
      };
      "Mod+WheelScrollUp" = {
        _props.cooldown-ms = 150;
        focus-workspace-up = {};
      };

      # ---- Overview + Fensterwechsel ----
      "Mod+Tab" = {
        _props.hotkey-overlay-title = "Overview";
        toggle-overview = {};
      };
      "Alt+Tab".focus-window-previous = {};

      # ---- Fenster/Spalte bewegen ----
      "Mod+Shift+H".move-column-left = {};
      "Mod+Shift+L".move-column-right = {};
      "Mod+Shift+Left".move-column-left = {};
      "Mod+Shift+Right".move-column-right = {};
      # MODIFIED 2026-10-06: move-window-* -> move-window-*-or-to-workspace-*,
      # damit die Shift-Ebene die Fokus-Ebene spiegelt. Innerhalb der Spalte
      # unveraendert; am Spaltenende wandert das Fenster jetzt auf den
      # Nachbar-Workspace, statt stehenzubleiben.
      "Mod+Shift+J".move-window-down-or-to-workspace-down = {};
      "Mod+Shift+K".move-window-up-or-to-workspace-up = {};
      "Mod+Shift+Down".move-window-down-or-to-workspace-down = {};
      "Mod+Shift+Up".move-window-up-or-to-workspace-up = {};

      # Mod+Shift+U/I BLEIBT, obwohl Mod+U/I weg ist. Das ist keine Schlamperei:
      # die Zeilen daruber bewegen das FENSTER, diese hier die ganze SPALTE.
      # Bei einer Spalte mit mehreren Fenstern (Mod+Comma) sind das zwei
      # verschiedene Operationen, und nur diese kann die zweite.
      "Mod+Shift+U".move-column-to-workspace-down = {};
      "Mod+Shift+I".move-column-to-workspace-up = {};

      "Mod+Alt+Left".swap-window-left = {};
      "Mod+Alt+Right".swap-window-right = {};

      # ---- Fokus: Monitor ----
      # ADDED 2026-10-06. Bis hierher kannte diese Config AUSSCHLIESSLICH
      # move-column-to-monitor-* (die zwei Zeilen darunter): Fenster liessen
      # sich auf den Nachbarmonitor werfen, der Fokus kam aber nicht
      # hinterher. Damit war jeder Monitor eine Sackgasse.
      #
      # WARUM DAS EINE EIGENE AKTIONSFAMILIE IST: in niri gehoeren
      # Workspaces dem OUTPUT, nicht dem System. Jeder Monitor fuehrt seinen
      # eigenen, dynamischen Stapel 1..n (siehe `niri msg workspaces`).
      # focus-workspace / focus-workspace-up/down weiter oben wirken deshalb
      # per Definition nur innerhalb des fokussierten Monitors — anders als
      # unter Hyprland, wo Workspace-Nummern global waren und ein Sprung auf
      # Workspace 3 implizit den Monitor wechselte.
      #
      # Richtung ist GEOMETRISCH, nicht per Index: niri liest die logischen
      # Positionen aus niriOutputs (hosts/<host>/variables.nix). Auf meo-work
      # steht der LG unter dem Dell (y=1080), nicht rechts daneben — dorthin
      # fuehrt also -down, nicht -right.
      "Mod+Ctrl+H".focus-monitor-left = {};
      "Mod+Ctrl+L".focus-monitor-right = {};
      "Mod+Ctrl+J".focus-monitor-down = {};
      "Mod+Ctrl+K".focus-monitor-up = {};

      # MODIFIED 2026-10-06: Mod+Ctrl+Left/Right waren focus-workspace-up/down.
      # Mit dem Workspace jetzt auf Mod+Up/Down (siehe oben) waere das doppelt
      # gemoppelt gewesen UND haette als einziges Bind die Hausregel dieser
      # Datei gebrochen, dass die Pfeile exakte Aliase der vi-Tasten sind:
      # Mod+Ctrl+H ist Monitor, also muss Mod+Ctrl+Left es auch sein.
      "Mod+Ctrl+Left".focus-monitor-left = {};
      "Mod+Ctrl+Right".focus-monitor-right = {};
      "Mod+Ctrl+Down".focus-monitor-down = {};
      "Mod+Ctrl+Up".focus-monitor-up = {};

      # ---- Spalte auf anderen Monitor ----
      # ADDED 2026-10-06 (down/up): es gab nur left/right. Auf meo-work war
      # das Laptop-Panel damit per Tastatur gar nicht als Ziel erreichbar,
      # weil es UNTER dem Dell haengt statt neben ihm.
      "Mod+Ctrl+Shift+H".move-column-to-monitor-left = {};
      "Mod+Ctrl+Shift+L".move-column-to-monitor-right = {};
      "Mod+Ctrl+Shift+J".move-column-to-monitor-down = {};
      "Mod+Ctrl+Shift+K".move-column-to-monitor-up = {};

      # ---- Layout: die eigentliche niri-Geste ----
      # Fenster in die Spalte links von sich einsaugen bzw. wieder rauswerfen.
      # Das ersetzt das, was in Hyprland "Fenster in Richtung X verschieben" war.
      "Mod+Comma" = {
        _props.hotkey-overlay-title = "Fenster in Spalte aufnehmen";
        consume-window-into-column = {};
      };
      "Mod+Period" = {
        _props.hotkey-overlay-title = "Fenster aus Spalte loesen";
        expel-window-from-column = {};
      };

      "Mod+R".switch-preset-column-width = {};
      "Mod+Minus".set-column-width = "-10%";
      # niri's default ist Mod+Equal, aber auf der Schweizer Tastatur liegt "="
      # auf LEVEL 2 von AE10 (Shift+0), also unerreichbar. Stattdessen verwendet
      # diese Config Mod+Apostrophe (LEVEL 1 von AE11), das layoutneutral
      # funktioniert.
      "Mod+Apostrophe".set-column-width = "+10%";
      "Mod+Ctrl+F".maximize-column = {};
      "Mod+Ctrl+Return".center-column = {};
      "Mod+Alt+T".toggle-column-tabbed-display = {};

      # Tritt an die Stelle des Special-Workspace-Toggles (Mod+Space /
      # Mod+Shift+Space unter Hyprland).
      "Mod+Space".switch-focus-between-floating-and-tiling = {};
      "Mod+Shift+Space".move-window-to-floating = {};

      # niris Default waere Mod+Shift+Slash. Auf dem Schweizer Layout liegt "/"
      # auf Shift+7, das kollidiert mit Mod+Shift+7. Mod+F1 ist layoutneutral.
      "Mod+F1".show-hotkey-overlay = {};
    };
}
