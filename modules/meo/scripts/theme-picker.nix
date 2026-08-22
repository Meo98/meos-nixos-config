{ pkgs, ... }:

# theme-picker: fzf-TUI zum Durchscrollen & Aktivieren von Stylix-Farbschemata
# (303 base16-Schemes mit Live-Farbvorschau) und UI-/Mono-Fonts. Die Auswahl
# wird deklarativ in modules/upstream/core/stylix.nix (zwischen THEME_PICKER_*-
# Markern) geschrieben und per `nh os switch` aktiviert. Logik in
# ./theme-picker.sh (getrennt gehalten, um Nix-${}-Escaping zu vermeiden).
#
# base16-schemes wird als Store-Pfad injiziert; nh/git/nix kommen aus dem
# Ambient-PATH (writeShellScriptBin leert PATH nicht), fzf & Texttools werden
# explizit vorangestellt, damit der Picker unabhängig vom User-Env läuft.

pkgs.writeShellScriptBin "theme-picker" ''
  export THEME_PICKER_SCHEMES_DIR="${pkgs.base16-schemes}/share/themes"
  # Globale FZF_DEFAULT_OPTS des Users neutralisieren und deterministisches
  # Vollbild-Layout erzwingen — sonst kann ein globales --height/--preview
  # die Liste/Vorschau des Pickers "leer" wirken lassen.
  export FZF_DEFAULT_OPTS="--height=100% --layout=reverse --border --info=inline"
  export PATH="${pkgs.lib.makeBinPath [
    pkgs.fzf
    pkgs.gnused
    pkgs.gawk
    pkgs.gnugrep
    pkgs.coreutils
    pkgs.diffutils
  ]}:$PATH"
  ${builtins.readFile ./theme-picker.sh}
''
