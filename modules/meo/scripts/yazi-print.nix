{ pkgs, ... }:

# yazi-print: opens the native GTK print dialog (yad --print) for the file
# currently hovered/selected in yazi. Dialog lets you choose paper size
# (A4/A3/Letter/Custom), orientation, copies, duplex, and printer.
#
# Triggered from yazi keymap (modules/upstream/home/yazi/keymap.nix) via:
#   { on = "<C-p>"; run = "shell 'yazi-print %s'"; ... }
#
# Replaces the older ~/.local/bin/yazi-print which used `lp` directly (no dialog)
# and tried to auto-detect PDF orientation via regex on MediaBox — the GTK
# dialog reads MediaBox itself and pre-selects orientation, so that logic is
# no longer needed.

pkgs.writeShellApplication {
  name = "yazi-print";
  runtimeInputs = with pkgs; [ yad ];
  text = ''
    for FILE in "$@"; do
      case "''${FILE,,}" in
        *.pdf)
          TYPE="PDF"
          ;;
        *.png | *.jpg | *.jpeg | *.gif | *.bmp | *.tiff | *.tif | *.webp)
          TYPE="IMAGE"
          ;;
        *)
          TYPE="TEXT"
          ;;
      esac
      # Open dialog; tolerate non-zero exit (user can cancel = exit 1).
      yad --print --type="$TYPE" --filename="$FILE" || true
    done
  '';
}
