{ pkgs, ... }:

# hilfe: farbiger Spickzettel der wichtigsten Befehle & Tastenkürzel dieses
# Setups — als Einstiegshilfe. Wird beim Terminalstart als Hinweis erwähnt
# (siehe Greeting in modules/upstream/home/zsh/default.nix) und ist jederzeit
# per `hilfe` aufrufbar.
pkgs.writeShellScriptBin "hilfe" ''
  b=$'\033[1m'; d=$'\033[2m'; r=$'\033[0m'
  mauve=$'\033[38;2;203;166;247m'; green=$'\033[38;2;166;227;161m'
  blue=$'\033[38;2;137;180;250m';  peach=$'\033[38;2;250;179;135m'
  text=$'\033[38;2;205;214;244m'

  head() { printf '\n  %s%s%s\n' "$mauve$b" "$1" "$r"; }
  row()  { printf '    %s%-22s%s %s%s%s\n' "$green" "$1" "$r" "$text" "$2" "$r"; }

  printf '%s╭─ %sSpickzettel%s%s ──────────────────────────────╮%s\n' \
    "$blue" "$b" "$r$blue" "" "$r"

  head "System"
  row "fr"              "System bauen + aktivieren (committet & pusht)"
  row "fu"              "Pakete/Inputs aktualisieren (flake update)"
  row "update"          "= fr (Kurzform)"

  head "Dateien"
  row "yy  /  yazi"     "Dateimanager im Terminal (q = zurück)"
  row "ls / ll / la"    "Auflisten (mit Icons) — la = auch versteckte"
  row "lt"              "Baum-Ansicht (2 Ebenen)"
  row "cd <name>"       "Springen (zoxide: lernt häufige Ordner)"
  row ".. / ..."        "ein / zwei Ordner hoch"
  row "mkcd <name>"     "Ordner anlegen und reinwechseln"

  head "Bearbeiten & Ansehen"
  row "v <datei>"       "Editor (nvim)   ·   sv = mit sudo"
  row "cat <datei>"     "Datei anzeigen (bat, mit Syntax-Farben)"
  row "tldr <befehl>"   "Knappe Beispiele zu einem Befehl"

  head "Aussehen"
  row "theme-picker"    "Farbschema & Schriftart wählen (mit Vorschau)"

  head "Terminal (Ghostty)"
  row "Strg+Shift+T"    "neuer Tab      ·  Strg+Tab = wechseln"
  row "Strg+Shift+E/O"  "Fenster teilen (rechts / unten)"
  row "Strg+Shift+W"    "Tab/Split schließen"
  row "Strg+R"          "Verlauf durchsuchen (atuin)"
  row "Tab-Taste"       "Vervollständigen — mit durchsuchbarem Menü + Vorschau"

  printf '\n  %sTipp:%s dieses Blatt jederzeit mit %shilfe%s aufrufen.%s\n\n' \
    "$d" "$r" "$peach$b" "$r$d" "$r"
''
