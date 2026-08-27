{pkgs, ...}:
pkgs.writeShellApplication {
  name = "keymap-popup";
  runtimeInputs = with pkgs; [imv procps];
  text = ''
    # Keyball-Keymap-Overlays (F13/F14/F15).
    #
    # Unter Hyprland war das ein bind/bindr-Paar: druecken zeigt, loslassen
    # versteckt. niri 26.04 kennt KEINE Release-Bindings — gueltige
    # Bind-Properties sind nur repeat, allow-when-locked, cooldown-ms,
    # hotkey-overlay-title und allow-inhibiting. Deshalb hier ein Toggle:
    # erneuter Tastendruck schliesst das Bild wieder.
    #
    # Der Marker "niri-keymap-popup" steht nur in der imv-Kommandozeile, nicht
    # im Namen dieses Scripts — sonst wuerde pkill -f sich selbst treffen.
    layer="''${1:-1}"
    img="$HOME/Pictures/Screenshots/keymap_layer''${layer}.png"

    if pkill -f 'niri-keymap-popup' 2>/dev/null; then
      exit 0
    fi

    if [ ! -f "$img" ]; then
      echo "keymap-popup: $img existiert nicht" >&2
      exit 1
    fi

    exec imv -n niri-keymap-popup "$img"
  '';
}
