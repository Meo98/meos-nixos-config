# DMS-Einstellungen, die beim ersten Start stimmen muessen.
#
# Die Datei setzt die MODUL-OPTION programs.dank-material-shell.settings; das
# Modul schreibt daraus ~/.config/DankMaterialShell/settings.json (siehe
# distro/nix/home.nix im DMS-Flake). Ein leeres Attrset erzeugt gar keine
# Datei, eine Teilmenge ist also der vorgesehene Fall — alles Uebrige bleibt
# bei DMS' Vorgaben.
#
# HIER STEHEN BEWUSST KEINE FARBEN, SCHRIFTEN ODER TRANSPARENZEN.
# stylix.targets.dank-material-shell ist in dieser Konfiguration bereits
# aktiv und setzt fontFamily, monoFontFamily, popupTransparency,
# dockTransparency, session.wallpaperPath und einen customThemeFile aus der
# base16-Palette. Wer hier dieselben Schluessel setzt, streitet mit Stylix.
#
# Gleiche Aufteilung wie modules/upstream/home/noctalia.nix: nur die Werte,
# die beim ersten Boot korrekt sein muessen; der Rest ueber die Oberflaeche.
{host, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
in {
  programs.dank-material-shell.settings = {
    # Bildschirm-Abschaltung. Auf meo AUS gegen den eDP-OLED-Freeze.
    fadeToDpmsEnabled = vars.dmsScreenOff or false;
    fadeToDpmsGracePeriod = 5;

    # Sperr-Zeiten in Sekunden, wie bisher unter Noctalia (600).
    acLockTimeout = 600;
    batteryLockTimeout = 600;

    # DMS' Dock ist per Default AUS (showDock = false, belegt in
    # quickshell/Common/SettingsData.qml). Ohne diese Zeile waere das Dock
    # nach dem Wechsel kommentarlos verschwunden — Noctalia hatte eines.
    showDock = true;
  };
}
