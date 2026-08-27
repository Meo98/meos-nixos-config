# Anwendungs-, Noctalia-, Screenshot- und Hardware-Binds.
#
# Portiert aus modules/upstream/home/hyprland/binds.nix. Die Noctalia-IPC-Syntax
# (noctalia msg panel-toggle …) ist compositor-unabhaengig und bleibt unveraendert.
#
# ENTFALLEN gegenueber Hyprland, mit Begruendung:
#   Mod+Ctrl+D  Dock        -> nwg-dock-hyprland ist Hyprland-only; Noctalia
#                              bringt einen eigenen Dock mit (dock.enabled=true)
#   Mod+Shift+N swaync-reset -> swaync laeuft bei barChoice="noctalia" gar nicht
#   Mod+K       qs-keybinds  -> war unter Hyprland bereits unerreichbar (Keysym K
#                              vs. k bei modmask 64); ersetzt durch das native
#                              show-hotkey-overlay auf Mod+F1 (binds-nav.nix)
#   Mod+Shift+K list-keybinds-> dito; Mod+Shift+K ist jetzt move-window-up
#   Mod+Alt+S   Region-Shot  -> die niri-Screenshot-UI (Mod+S) startet ohnehin
#                              in der Regionsauswahl
#   Mod+Shift+W qs-wallpapers-apply -> war unter Hyprland doppelt belegt; hier
#                              gewinnt eindeutig das Noctalia-Wallpaper-Panel
{host, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
  inherit (vars) browser terminal;
in {
  wayland.windowManager.niri.settings.binds = {
    # ---- Terminal und Anwendungen ----
    "Mod+Return" = {
      _props.hotkey-overlay-title = "Terminal";
      spawn = [terminal];
    };
    "Mod+W" = {
      _props.hotkey-overlay-title = "Browser";
      spawn = [browser];
    };
    "Mod+Y".spawn = ["kitty" "-e" "yazi"];
    "Mod+E".spawn = ["emopicker9000"];
    "Mod+O".spawn = ["obs"];
    "Mod+G".spawn = ["gimp"];
    "Mod+T".spawn = ["thunar"];
    "Mod+Alt+M".spawn = ["pavucontrol"];
    "Mod+Shift+D".spawn = ["discord"];
    "Mod+Alt+W".spawn = ["web-search"];
    "Mod+Ctrl+C".spawn = ["qs-cheatsheets"];

    # Ersatz fuer den pyprland-Scratchpad. Siehe modules/meo/scripts/niri-term-toggle.nix.
    "Mod+Shift+T" = {
      _props.hotkey-overlay-title = "Terminal-Workspace";
      spawn = ["niri-term-toggle"];
    };

    # ---- Noctalia (IPC unveraendert aus binds.nix) ----
    "Mod+D".spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
    "Mod+Shift+Return".spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
    "Mod+M".spawn = ["noctalia" "msg" "panel-toggle" "control-center" "notifications"];
    "Mod+V".spawn = ["noctalia" "msg" "panel-toggle" "clipboard"];
    "Mod+C".spawn = ["noctalia" "msg" "panel-toggle" "control-center"];
    "Mod+X".spawn = ["noctalia" "msg" "panel-toggle" "session"];
    "Mod+Shift+W".spawn = ["noctalia" "msg" "panel-toggle" "wallpaper"];
    "Mod+Alt+P".spawn = ["noctalia" "msg" "settings-toggle"];
    "Mod+Shift+Comma".spawn = ["noctalia" "msg" "settings-toggle"];

    # sleep 0.5 haelt dasselbe Schutzfenster wie unter Hyprland: es gibt
    # Noctalia Zeit, das Lock-Surface zu committen, bevor logind suspendiert.
    "Mod+Alt+L" = {
      _props.hotkey-overlay-title = "Sperren und Suspend";
      spawn-sh = "loginctl lock-session && sleep 0.5 && systemctl suspend";
    };

    # ---- Fenster und Session ----
    "Mod+Q".close-window = {};
    "Mod+F".fullscreen-window = {};
    "Mod+Shift+F".toggle-window-floating = {};
    "Mod+Shift+C".quit = {};

    # ---- Screenshots (nativ statt hyprshot) ----
    "Mod+S" = {
      _props.hotkey-overlay-title = "Screenshot";
      screenshot = {};
    };
    "Mod+Ctrl+S".screenshot-screen = {};
    "Mod+Shift+S".screenshot-window = {};

    # niri hat mit `niri msg pick-color` einen eingebauten Picker, der die Farbe
    # aber nur auf stdout schreibt. wl-color-picker legt sie direkt in die
    # Zwischenablage und zeigt eine Lupe. Native Alternative ohne Extrapaket:
    #   spawn-sh = "niri msg pick-color | wl-copy";
    "Mod+Alt+C".spawn = ["wl-color-picker"];

    # ---- Keyball-Overlays (Toggle statt Halten, siehe Task 5) ----
    "F13".spawn = ["keymap-popup" "1"];
    "F14".spawn = ["keymap-popup" "2"];
    "F15".spawn = ["keymap-popup" "3"];

    # ---- Audio und Helligkeit ----
    # allow-when-locked, damit die Tasten auch auf dem Lockscreen wirken.
    "XF86AudioRaiseVolume" = {
      _props.allow-when-locked = true;
      spawn = ["vol-smart" "up" "5%" "5%" "20%"];
    };
    "XF86AudioLowerVolume" = {
      _props.allow-when-locked = true;
      spawn = ["vol-smart" "down" "5%" "5%" "20%"];
    };
    "XF86AudioMute" = {
      _props.allow-when-locked = true;
      spawn = ["vol-smart" "mute"];
    };
    "XF86AudioPlay" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "play-pause"];
    };
    "XF86AudioPause" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "play-pause"];
    };
    "XF86AudioNext" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "next"];
    };
    "XF86AudioPrev" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "previous"];
    };
    "XF86MonBrightnessUp" = {
      _props.allow-when-locked = true;
      spawn = ["bright-smart" "up" "10" "5%" "card0-HDMI-A-1" "0.2"];
    };
    "XF86MonBrightnessDown" = {
      _props.allow-when-locked = true;
      spawn = ["bright-smart" "down" "10" "5%" "card0-HDMI-A-1" "0.2"];
    };
  };
}
