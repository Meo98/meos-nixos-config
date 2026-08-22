{ pkgs, ... }:

# theme-picker: fzf-TUI zum Durchscrollen & Aktivieren von Stylix-Farbschemata
# (303 base16-Schemes mit Live-Editor-Vorschau) und UI-/Mono-Fonts (mit echter,
# als Bild gerenderter Schrift-Vorschau via imagemagick+chafa). Die Auswahl wird
# deklarativ in modules/upstream/core/stylix.nix (zwischen THEME_PICKER_*-Markern)
# geschrieben und per `nh os switch` aktiviert. Logik in ./theme-picker.sh
# (getrennt gehalten, um Nix-${}-Escaping zu vermeiden).
#
# base16-schemes + alle Font-Dateien werden als Store-Pfade injiziert (fontsDir =
# symlinkJoin aller anbietbaren Fonts, damit die Bild-Vorschau die echte reguläre
# Schnittdatei findet). nh/git/nix kommen aus dem Ambient-PATH; fzf, Texttools,
# imagemagick & chafa werden explizit vorangestellt.

let
  fontPkgs = with pkgs; [
    nerd-fonts.jetbrains-mono nerd-fonts.fira-code nerd-fonts.hack
    nerd-fonts.iosevka nerd-fonts.meslo-lg nerd-fonts.caskaydia-cove
    nerd-fonts.sauce-code-pro nerd-fonts.commit-mono nerd-fonts.geist-mono
    noto-fonts inter dejavu_fonts cantarell-fonts fira roboto work-sans
    ubuntu-classic source-sans
  ];
  fontsDir = pkgs.symlinkJoin {
    name = "theme-picker-fonts";
    paths = fontPkgs;
  };
in
pkgs.writeShellScriptBin "theme-picker" ''
  export THEME_PICKER_SCHEMES_DIR="${pkgs.base16-schemes}/share/themes"
  export THEME_PICKER_FONTS_DIR="${fontsDir}/share/fonts"
  # Globale FZF_DEFAULT_OPTS neutralisieren + deterministisches Vollbild-Layout,
  # sonst kann ein globales --height/--preview die Liste "leer" wirken lassen.
  export FZF_DEFAULT_OPTS="--height=100% --layout=reverse --border --info=inline"
  export PATH="${pkgs.lib.makeBinPath [
    pkgs.fzf
    pkgs.gnused
    pkgs.gawk
    pkgs.gnugrep
    pkgs.coreutils
    pkgs.diffutils
    pkgs.findutils
    pkgs.imagemagick
    pkgs.chafa
  ]}:$PATH"
  ${builtins.readFile ./theme-picker.sh}
''
