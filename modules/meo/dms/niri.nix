# DMS' niri-Integration.
#
# DMS' eigenes homeModules.niri wird BEWUSST NICHT IMPORTIERT. Es setzt in
# seinem config-Block unbedingt `programs.niri.settings` — eine Option aus
# niri-flake. Dieses Repo benutzt das nixpkgs-HM-Modul, dessen Config unter
# wayland.windowManager.niri liegt; `programs.niri` existiert hier gar nicht
# (gemessen 2026-08-31: programs.* kennt nur "niriswitcher"). Ein Import
# braeche mit "option programs.niri.settings does not exist".
#
# Das ist kein Verlust: das Modul verdrahtet nur die include-Zeilen. Die
# KDL-Dateien selbst schreibt DMS zur LAUFZEIT aus eingebetteten Vorlagen
# (core/internal/config/embedded/niri-*.kdl, quickshell/Services/
# niri-wpblur.kdl, Farben ueber quickshell/matugen/configs/niri.toml).
# Wir binden sie hier nur ein.
#
# REIHENFOLGE IST DER GANZE PUNKT: niri-Includes sind positional, spaetere
# ueberschreiben fruehere, und Fensterregeln werden an der include-Zeile
# eingefuegt. DMS' Dateien stehen deshalb ZUERST und die eigene Config
# ZULETZT.
#
# Daraus folgt, dass wir GROSSZUEGIG einbinden koennen: wo eigene Werte
# existieren, gewinnen sie ohnehin; wo keine existieren, gilt DMS' Vorgabe.
# Genau das ist der Wunsch — so viel DMS-Default wie moeglich, aber die
# eigene Tastenbelegung unangetastet. Konkret bleiben Mod+Space
# (Floating/Tiling), Mod+Comma (Fenster in Spalte), Mod+V/X/M und die
# Multimedia-Tasten mit vol-smart/bright-smart bei ihrer Belegung, waehrend
# Mod+N, Mod+P und Mod+Alt+N von DMS dazukommen.
#
# optional=true gibt es seit niri 26.04 (hier im Einsatz): fehlt eine Datei —
# etwa beim allerersten Start, bevor DMS sie geschrieben hat —, ist das eine
# Warnung im Log statt eines Config-Fehlers, der die Session lahmlegen wuerde.
#
# Die Dateinamen sind gegen "dms setup --help" gemessen (2026-08-31):
# alttab, binds, colors, cursor, layout, outputs, windowrules sind die
# CLI-Unterbefehle. binds.kdl wird ABSICHTLICH NICHT eingebunden — es ist
# praktisch der volle niri-Standard-Keymap, nicht bloss DMS-Extras, und die
# eigene Belegung soll unveraendert bleiben. wpblur.kdl hat keinen CLI-Befehl
# und entsteht erst zur Laufzeit des Shells; optional=true faengt das ab.
{lib, ...}: {
  # 1. Die vom HM-Modul erzeugte Config nach niri/hm.kdl umleiten.
  xdg.configFile."niri/config.kdl".target = lib.mkForce "niri/hm.kdl";

  # 2. Eigene niri/config.kdl, die erst DMS' Dateien und dann hm.kdl einbindet.
  xdg.configFile."niri/config-dms" = {
    target = "niri/config.kdl";
    text = ''
      include optional=true "dms/colors.kdl"
      include optional=true "dms/layout.kdl"
      include optional=true "dms/alttab.kdl"
      include optional=true "dms/outputs.kdl"
      include optional=true "dms/cursor.kdl"
      include optional=true "dms/windowrules.kdl"
      include optional=true "dms/wpblur.kdl"
      include optional=true "hm.kdl"
    '';
  };
}
