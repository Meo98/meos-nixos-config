# ADDED 2026-11-03: Eine Tabelle fuer die Control-Ports der ArtCraft-GUIs,
# gelesen von zwei Modulen:
#   artcraft.nix     -> der Starter `<app>` haengt `--control <port>` an, damit
#                       jede GUI von Anfang an fuer Claude Code steuerbar ist
#   claude-code.nix  -> der MCP-Server `<app>-cli mcp` haengt sich an diesen
#                       Port, wenn er beim Start offen ist (sonst headless)
#
# Felder je App:
#   port        Control-Port der GUI (loopback-only, pro App eindeutig)
#   launchArgs  was der GUI-Starter anhaengt; null = GUI startet ohne
#               Control-Port (Grund steht im Kommentar)
#   connect     Flags, mit denen `<app>-cli mcp` sich an die GUI haengt;
#               null = der MCP-Server kennt keinen Bridge-Modus
#   mcpArgs     (optional) Flags, die `<app>-cli mcp` IMMER bekommt, verbunden
#               wie headless. Shell-Text, $HOME wird beim Start aufgeloest.
#
# Die CLIs unterscheiden sich in der Flag-Syntax (--connect PORT,
# --connect HOST:PORT, --bridge ...) und darin, was ohne laufende App
# passiert (manche brechen ab, andere fallen auf headless zurueck); der
# Wrapper in claude-code.nix vereinheitlicht das. Alle Ports ohne Auth
# ausser photocraft (Token-Datei, legt die GUI beim ersten Start mit 0600
# an). Verifiziert 2026-10-16 / 2026-11-03 gegen artcraft-versions.json.
let
  tokenFile = ''"$HOME/.config/photocraft/control.token"'';
in {
  photocraft = {
    port = 7971;
    launchArgs = "--control 7971 --control-token-file ${tokenFile}";
    connect = "--bridge 127.0.0.1:7971 --control-token-file ${tokenFile}";
  };
  vectorcraft = {
    port = 7972;
    launchArgs = "--control 7972";
    connect = "--connect 127.0.0.1:7972";
  };
  lightcraft = {
    port = 7973;
    launchArgs = "--control 7973";
    connect = "--connect 127.0.0.1:7973";
  };
  # filmcraft: die GUI verlangt zu --control zusaetzlich FILMCRAFT_CONTROL_TOKEN
  # (64 Hex-Zeichen); wie `filmcraft-cli mcp --bridge` den Token mitgibt, ist
  # noch nicht geklaert -> Control-Modus vorerst nur von Hand.
  filmcraft = {
    port = 7974;
    launchArgs = null;
    connect = "--bridge 127.0.0.1:7974";
  };
  effectcraft = {
    port = 7975;
    launchArgs = "--control 7975";
    connect = "--bridge 7975";
  };
  # pdfcraft: GUI-Steuerung nur ueber eine Socket-DATEI (`pdfcraft --control
  # FILE`, `pdfcraft-cli ui --control FILE`), der MCP-Server kennt keinen
  # Bridge-Modus -> nur headless.
  pdfcraft = {
    port = null;
    launchArgs = null;
    connect = null;
  };
  wordcraft = {
    port = 7977;
    launchArgs = "--control 7977";
    connect = "--connect 127.0.0.1:7977";
  };
  gridcraft = {
    port = 7978;
    launchArgs = "--control 7978";
    connect = "--connect 7978";
  };
  # designcraft behaelt das Upstream-Beispiel 7979.
  designcraft = {
    port = 7979;
    launchArgs = "--control 7979";
    connect = "--connect 7979";
  };
  # deckcraft: 0.7.0 kannte kein --control; die aktuelle Version (siehe
  # artcraft-versions.json) hat GUI `--control PORT` und CLI `--connect PORT`.
  deckcraft = {
    port = 7980;
    launchArgs = "--control 7980";
    connect = "--connect 7980";
  };
  soundcraft = {
    port = 7981;
    launchArgs = "--control 7981";
    connect = "--connect 7981";
  };
  # --lazy: verbindet erst beim ersten Aufruf, bricht also auch dann nicht ab,
  # wenn die App erst spaeter startet.
  cadcraft = {
    port = 7982;
    launchArgs = "--control 7982";
    connect = "--connect 127.0.0.1:7982 --lazy";
  };
  # craft-anything 0.2.0: `craft-anything-cli mcp` kennt weder --connect noch
  # --bridge (nur --project/--inbox/--deep) -> nur headless. Die GUI beantwortet
  # Rueckfragen des Agenten ueber einen Inbox-Ordner (--inbox), nicht ueber
  # einen Control-Port.
  craft-anything = {
    port = null;
    launchArgs = null;
    connect = null;
  };
  # ADDED 2026-11-13: solidcraft (tangency-labs, Paket in artcraft.nix).
  # Verifiziert gegen 0.41.0 und docs/mcp.md des Releases:
  #   - GUI `--control PORT`; jede Verbindung braucht den Token, den die App
  #     pro Start neu schreibt. `solidcraft-cli mcp --connect` liest ihn selbst
  #     aus der Token-Datei im Datenordner, hier ist nichts zu hinterlegen.
  #   - Dateizugriff des MCP-Servers ist auf den Ordner des offenen Designs
  #     beschraenkt. --allow-path gibt zusaetzlich ~/Dokumente frei (dort
  #     liegen die Projektordner), sonst scheitert Speichern/Export an
  #     "outside the folders this agent may use".
  solidcraft = {
    port = 7983;
    launchArgs = "--control 7983";
    connect = "--connect 127.0.0.1:7983";
    mcpArgs = ''--allow-path "$HOME/Dokumente"'';
  };
}
