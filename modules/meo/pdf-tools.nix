{ pkgs, ... }:

# PDF tools — installed centrally so both meo and meo-work hosts have them.
#
# zathura is a minimalist PDF viewer:
#   - vim-style keybindings (j/k scroll, gg/G top/bottom, / search)
#   - Native GTK print dialog on Ctrl+P (same dialog yazi-print uses)
#   - <100ms startup (no GUI bloat) — better than onlyoffice for PDF viewing
#   - Bound to application/pdf in hosts/<host>/default.nix
#
# poppler_utils provides pdfinfo/pdftotext/pdfunite/pdfseparate — useful for
# print-prep workflows (split an A3 plan into 2x A4, query page count, etc.)
{
  home.packages = with pkgs; [
    zathura
    poppler-utils
  ];

  # Persist last-used directory and other zathura state under XDG.
  xdg.configFile."zathura/zathurarc".text = ''
    # Sane defaults for technical PDF viewing (electrical plans, datasheets)
    set selection-clipboard clipboard
    set adjust-open width
    set scroll-step 80
    set zoom-step 20
    set window-title-basename true
    set statusbar-h-padding 4
    set statusbar-v-padding 2
    # Dark mode toggle on `i` (default)
    set recolor-darkcolor "#d8d8d8"
    set recolor-lightcolor "#1e1e2e"
  '';
}
