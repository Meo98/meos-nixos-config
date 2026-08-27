# Navigation, Fenster bewegen, Layout-Manipulation.
#
# Schema laut Spec Abschnitt 7 (Hybrid):
#   - h/l und Pfeil links/rechts wechseln die SPALTE (Achsenwechsel gegenueber
#     Hyprland, wo es Richtungsfokus war)
#   - j/k und Pfeil hoch/runter wechseln das Fenster INNERHALB der Spalte
#     (wie bisher)
#   - u/i wechseln den Workspace (neu; Workspaces sind in niri vertikal)
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
    {key = "1"; ws = 1;}
    {key = "2"; ws = 2;}
    {key = "3"; ws = 3;}
    {key = "4"; ws = 4;}
    {key = "5"; ws = 5;}
    {key = "6"; ws = 6;}
    {key = "7"; ws = 7;}
    {key = "8"; ws = 8;}
    {key = "9"; ws = 9;}
    {key = "0"; ws = 10;}
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
      "Mod+H".focus-column-left = {};
      "Mod+L".focus-column-right = {};
      "Mod+Left".focus-column-left = {};
      "Mod+Right".focus-column-right = {};

      # ---- Fokus: Fenster in der Spalte ----
      "Mod+J".focus-window-down = {};
      "Mod+K".focus-window-up = {};
      "Mod+Down".focus-window-down = {};
      "Mod+Up".focus-window-up = {};

      # ---- Fokus: Workspace (vertikal) ----
      "Mod+U".focus-workspace-down = {};
      "Mod+I".focus-workspace-up = {};
      "Mod+Ctrl+Left".focus-workspace-up = {};
      "Mod+Ctrl+Right".focus-workspace-down = {};

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
      "Mod+Shift+J".move-window-down = {};
      "Mod+Shift+K".move-window-up = {};
      "Mod+Shift+Down".move-window-down = {};
      "Mod+Shift+Up".move-window-up = {};
      "Mod+Shift+U".move-column-to-workspace-down = {};
      "Mod+Shift+I".move-column-to-workspace-up = {};

      "Mod+Alt+Left".swap-window-left = {};
      "Mod+Alt+Right".swap-window-right = {};

      "Mod+Ctrl+Shift+H".move-column-to-monitor-left = {};
      "Mod+Ctrl+Shift+L".move-column-to-monitor-right = {};

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
      "Mod+Equal".set-column-width = "+10%";
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
