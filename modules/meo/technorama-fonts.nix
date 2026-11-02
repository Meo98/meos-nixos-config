{ config, ... }:
# Technorama-Hausschriften (Forme Grotesque, ES Allianz, T-Star, Vista) für alle
# Programme, die über fontconfig Schriften suchen: WordCraft/ArtCraft (Sandbox
# bindet /etc/fonts und $HOME), OnlyOffice, LibreOffice, Browser.
#
# Die Schriften sind lizenziert und liegen nicht im Nix-Store, sondern im
# Vorlagen-Ordner (Syncthing auf beiden Hosts). Hier wird nur ein Symlink
# nach ~/.local/share/fonts gesetzt; fontconfig liest den Ordner rekursiv.
# Fehlt der Vorlagen-Ordner, zeigt der Symlink ins Leere und fontconfig
# ignoriert ihn still.
let
  schriften = "${config.home.homeDirectory}/Dokumente/Technorama_Projekte/Vorlagen/01_CI/Schriften";
in {
  xdg.dataFile."fonts/technorama".source = config.lib.file.mkOutOfStoreSymlink schriften;
}
