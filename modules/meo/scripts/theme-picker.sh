# theme-picker — fzf-TUI zum Durchscrollen & Aktivieren von Stylix-Farbschemata
# und UI-/Mono-Fonts. Schreibt die Auswahl deklarativ in
#   modules/upstream/core/stylix.nix  (zwischen THEME_PICKER_*-Markern)
# und aktiviert sie per `nh os switch`. Die Änderung landet im Working-Tree
# und wird beim nächsten `fr` automatisch committet/gepusht.
#
# Wird via modules/meo/scripts/theme-picker.nix gewrappt (setzt PATH +
# THEME_PICKER_SCHEMES_DIR und liest diese Datei per readFile ein).

SCHEMES_DIR="${THEME_PICKER_SCHEMES_DIR:?SCHEMES_DIR fehlt}"
FLAKE="$HOME/nixos-config"
STYLIX="$FLAKE/modules/upstream/core/stylix.nix"
BACKUP=""

# ── Farb-Helfer für die Themed-Vorschau (globale Arrays C=r;g;b, H=hex) ───
declare -A C H
W=50; VIS=0
_bg()  { printf '\033[48;2;%sm' "${C[$1]}"; }
_fg()  { printf '\033[38;2;%sm' "${C[$1]}"; }
_rst() { printf '\033[0m'; }
_row() { _bg "$1"; VIS=0; }                       # Zeile starten: bg = base$1
_seg() { _fg "$1"; printf '%s' "$2"; VIS=$((VIS + ${#2})); }  # fg $1 + ASCII-Text
_end() { local p=$((W - VIS)); [ "$p" -gt 0 ] && printf '%*s' "$p" ''; _rst; printf '\n'; }
_swatch() { printf '\033[48;2;%sm  \033[0m' "${C[$1]}"; }

# ── Vorschau: Scheme als echte Editor-Simulation rendern ─────────────────
# base16-Rollen (Standard): 00 Hintergrund · 01 Bar/Zeile · 02 Selektion
# 03 Kommentar · 05 Text · 08 rot/Variable · 09 orange/Zahl · 0A gelb/Klasse
# 0B grün/String · 0C cyan · 0D blau/Funktion · 0E lila/Keyword
scheme_preview() {
  local name="$1" f="$SCHEMES_DIR/$1.yaml" i hex
  [ -f "$f" ] || { echo "  (kein Scheme: $1)"; return; }
  for i in 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F; do
    hex=$(grep -iE "base$i:" "$f" | grep -oiE '[0-9a-f]{6}' | head -1)
    [ -n "$hex" ] || hex=000000
    H[$i]="$hex"
    C[$i]="$((16#${hex:0:2}));$((16#${hex:2:2}));$((16#${hex:4:2}))"
  done
  W=$(( ${FZF_PREVIEW_COLUMNS:-52} - 2 ))
  [ "$W" -gt 54 ] && W=54; [ "$W" -lt 22 ] && W=22

  local disp var auth
  disp=$(sed -n 's/^name:[[:space:]]*"\(.*\)"/\1/p' "$f" | head -1)
  var=$(sed -n 's/^variant:[[:space:]]*"\(.*\)"/\1/p' "$f" | head -1)
  auth=$(sed -n 's/^author:[[:space:]]*"\(.*\)"/\1/p' "$f" | head -1)
  printf '  \033[1m%s\033[0m  (%s)  -  %s\n\n' "$disp" "${var:-?}" "${auth:-?}"

  # Fenster-Titelleiste (bg base01)
  _row 01; _seg 05 " o o o   editor  -  theme.nix"; _end
  # Code mit Syntax-Highlighting (bg base00)
  _row 00; _seg 03 " 1  "; _seg 03 "# colorscheme preview";                 _end
  _row 00; _seg 03 " 2  "; _seg 0E "let"; _seg 05 " accent "; _seg 05 "= "; _seg 0B "\"#${H[0D]}\""; _end
  _row 00; _seg 03 " 3  "; _seg 0E "fn "; _seg 0D "greet"; _seg 05 "("; _seg 08 "name"; _seg 05 ") {"; _end
  # markierte/aktive Zeile (bg base02 = Selektionsfarbe)
  _row 02; _seg 05 " 4    "; _seg 0E "return "; _seg 08 "name"; _seg 05 " + "; _seg 09 "42"; _end
  _row 00; _seg 03 " 5  "; _seg 05 "}";                                     _end
  _row 00; _seg 0B " +  added line";                                        _end
  _row 00; _seg 08 " -  removed line";                                      _end
  # Statusleiste (bg base01)
  _row 01; _seg 0B " NORMAL "; _seg 0A " main* "; _seg 04 "  utf-8  ln 4:12"; _end
  printf '\n'

  # ANSI-Terminalfarben + Basistöne als kleine Referenz
  printf '  Terminal '; for i in 08 09 0A 0B 0C 0D 0E 0F; do _swatch "$i"; done; printf '\n'
  printf '  Basis    '; for i in 00 01 02 03 04 05 06 07; do _swatch "$i"; done; printf '\n\n'
  printf '  \033[38;2;%smKeyword\033[0m  \033[38;2;%smFunktion\033[0m  ' "${C[0E]}" "${C[0D]}"
  printf '\033[38;2;%smString\033[0m  \033[38;2;%smZahl\033[0m  \033[38;2;%smrot\033[0m\n' \
    "${C[0B]}" "${C[09]}" "${C[08]}"
}

# ── Vorschau: Font-Metadaten ─────────────────────────────────────────────
font_preview() {
  local row="$1" disp attr fname
  disp=$(printf '%s' "$row" | awk -F'|' '{print $1}')
  attr=$(printf '%s' "$row" | awk -F'|' '{print $2}')
  fname=$(printf '%s' "$row" | awk -F'|' '{print $3}')
  printf '  \033[1m%s\033[0m\n\n' "$disp"
  printf '  Nix-Paket:   pkgs.%s\n  Fontconfig:  "%s"\n\n' "$attr" "$fname"
  printf '  Echte Glyphen erscheinen erst nach dem Rebuild\n'
  printf '  (der Font wird dann erst installiert).\n\n'
  printf '  Pangram:  The quick brown fox jumps over the lazy dog\n'
  printf '  Ziffern:  0123456789   Zeichen:  {}[]()<>/\\|=+-*_\n'
  printf '  Ligaturen (Mono): != == === => -> <=  :::\n'
}

# ── stylix.nix: Zeile zwischen zwei Markern ersetzen ─────────────────────
replace_block() {
  local b="$1" e="$2" repl="$3"
  awk -v b="$b" -v e="$e" -v repl="$repl" '
    index($0,b){print; if(repl!="") print repl; inb=1; next}
    index($0,e){inb=0; print; next}
    inb{next}
    {print}
  ' "$STYLIX" > "$STYLIX.tmp" && mv "$STYLIX.tmp" "$STYLIX"
}

set_scheme() {
  # Achtung: bewusst die Nix-Expression ${pkgs.base16-schemes} schreiben
  # (nicht den Store-Pfad) -> bleibt über nixpkgs-Bumps reproduzierbar.
  local line='    base16Scheme = "${pkgs.base16-schemes}/share/themes/'"$1"'.yaml";'
  replace_block "THEME_PICKER_SCHEME_BEGIN" "THEME_PICKER_SCHEME_END" "$line"
}
set_wallpaper() {
  replace_block "THEME_PICKER_SCHEME_BEGIN" "THEME_PICKER_SCHEME_END" ""
}
set_mono() {
  local line='      monospace = { package = pkgs.'"$1"'; name = "'"$2"'"; };'
  replace_block "THEME_PICKER_MONO_BEGIN" "THEME_PICKER_MONO_END" "$line"
}
set_sans() {
  local line='      sansSerif = { package = pkgs.'"$1"'; name = "'"$2"'"; };'
  replace_block "THEME_PICKER_SANS_BEGIN" "THEME_PICKER_SANS_END" "$line"
}

# ── aktuellen Stand aus der Datei lesen (für die Menü-Anzeige) ───────────
current_scheme() {
  local l
  l=$(awk '/THEME_PICKER_SCHEME_BEGIN/{f=1;next} /THEME_PICKER_SCHEME_END/{f=0} f' \
        "$STYLIX" | grep -i base16Scheme)
  if [ -z "$l" ]; then echo "Wallpaper-Palette"; else
    printf '%s' "$l" | grep -oE '[^/"]+\.yaml' | sed 's/\.yaml$//'
  fi
}
current_font() { # $1 = MONO|SANS
  awk -v b="THEME_PICKER_$1_BEGIN" -v e="THEME_PICKER_$1_END" \
    'index($0,b){f=1;next} index($0,e){f=0} f' "$STYLIX" \
    | grep -oE 'name = "[^"]*"' | sed 's/name = "//; s/"$//'
}

# ── Font-Kataloge (Display|nixAttr|fontconfigName) ───────────────────────
mono_list() {
  printf '%s\n' \
    'JetBrains Mono|nerd-fonts.jetbrains-mono|JetBrains Mono' \
    'FiraCode|nerd-fonts.fira-code|FiraCode Nerd Font' \
    'Hack|nerd-fonts.hack|Hack Nerd Font' \
    'Iosevka|nerd-fonts.iosevka|Iosevka Nerd Font' \
    'MesloLGS|nerd-fonts.meslo-lg|MesloLGS Nerd Font' \
    'CaskaydiaCove (Cascadia)|nerd-fonts.caskaydia-cove|CaskaydiaCove Nerd Font' \
    'SauceCodePro (Source)|nerd-fonts.sauce-code-pro|SauceCodePro Nerd Font' \
    'CommitMono|nerd-fonts.commit-mono|CommitMono Nerd Font' \
    'GeistMono|nerd-fonts.geist-mono|GeistMono Nerd Font'
}
sans_list() {
  # Nur metrik-sichere Fonts: breite Fonts (z.B. Montserrat) sprengen
  # hartkodierte Qt/GTK-Dialogbreiten (siehe Kommentar in stylix.nix).
  printf '%s\n' \
    'Noto Sans (Standard)|noto-fonts|Noto Sans' \
    'Inter|inter|Inter' \
    'DejaVu Sans|dejavu_fonts|DejaVu Sans' \
    'Cantarell|cantarell-fonts|Cantarell' \
    'Fira Sans|fira|Fira Sans' \
    'Roboto|roboto|Roboto' \
    'Work Sans|work-sans|Work Sans' \
    'Ubuntu|ubuntu-classic|Ubuntu' \
    'Source Sans|source-sans|Source Sans 3'
}

# ── interaktive Auswahl ──────────────────────────────────────────────────
pick_scheme() {
  local sel
  sel=$( ( cd "$SCHEMES_DIR" && ls ./*.yaml ) | sed 's#.*/##; s/\.yaml$//' | sort \
    | fzf --ansi --prompt='Farbschema> ' --no-sort \
          --preview='theme-picker --scheme-preview {}' \
          --preview-window='right,58%,wrap,<90(down,55%)' \
          --header="Enter=übernehmen · ESC=zurück · aktuell: $(current_scheme)")
  [ -n "$sel" ] && { set_scheme "$sel"; echo "→ Schema: $sel  (noch nicht angewandt)"; }
}
pick_mono() {
  local row attr name
  row=$(mono_list | fzf -d'|' --with-nth=1 --prompt='Mono-Font> ' \
          --preview='theme-picker --font-preview {}' --preview-window='right,58%,wrap,<90(down,55%)' \
          --header="Enter=übernehmen · ESC=zurück · aktuell: $(current_font MONO)")
  [ -n "$row" ] || return
  attr=$(printf '%s' "$row" | awk -F'|' '{print $2}')
  name=$(printf '%s' "$row" | awk -F'|' '{print $3}')
  set_mono "$attr" "$name"; echo "→ Mono-Font: $name  (noch nicht angewandt)"
}
pick_sans() {
  local row attr name
  row=$(sans_list | fzf -d'|' --with-nth=1 --prompt='Sans-Font (UI)> ' \
          --preview='theme-picker --font-preview {}' --preview-window='right,58%,wrap,<90(down,55%)' \
          --header="Enter=übernehmen · ESC=zurück · aktuell: $(current_font SANS) · nur metrik-sichere Fonts")
  [ -n "$row" ] || return
  attr=$(printf '%s' "$row" | awk -F'|' '{print $2}')
  name=$(printf '%s' "$row" | awk -F'|' '{print $3}')
  set_sans "$attr" "$name"; echo "→ Sans-Font: $name  (noch nicht angewandt)"
}

apply() {
  local host; host=$(hostname)
  echo; echo "Baue & aktiviere neue Generation für '$host' … (sudo-Passwort möglich)"; echo
  if NH_FLAKE="$FLAKE" nh os switch --hostname "$host"; then
    echo; echo "✅ Aktiviert. Die Änderung liegt im Working-Tree von $FLAKE und wird"
    echo "   beim nächsten 'fr' automatisch committet & gepusht."
    cp "$STYLIX" "$BACKUP"   # neuer bekannter guter Stand
  else
    echo; echo "❌ Build fehlgeschlagen — stelle vorherige stylix.nix wieder her."
    cp "$BACKUP" "$STYLIX"
    echo "   System unverändert."
  fi
}
discard() { cp "$BACKUP" "$STYLIX"; echo "↩ Verworfen: stylix.nix auf Startzustand zurückgesetzt."; }

main() {
  [ -f "$STYLIX" ] || { echo "FEHLER: $STYLIX nicht gefunden." >&2; exit 1; }
  if ! grep -q THEME_PICKER_SCHEME_BEGIN "$STYLIX"; then
    echo "FEHLER: THEME_PICKER-Marker fehlen in stylix.nix." >&2; exit 1
  fi
  BACKUP=$(mktemp -t stylix.XXXXXX)
  cp "$STYLIX" "$BACKUP"
  trap 'rm -f "$BACKUP" "$STYLIX.tmp"' EXIT

  local action
  while true; do
    action=$(printf '%s\n' \
      "1 · Farbschema wählen         (aktuell: $(current_scheme))" \
      "2 · Mono-Font / Terminal      (aktuell: $(current_font MONO))" \
      "3 · Sans-Font / UI            (aktuell: $(current_font SANS))" \
      "4 · Farben aus Wallpaper generieren" \
      "5 · ✅ Anwenden & aktivieren (Rebuild)" \
      "6 · ↩ Änderungen verwerfen" \
      "q · Beenden" \
      | fzf --prompt='theme-picker> ' --no-sort --reverse \
            --header='Auswahl wird erst mit „Anwenden" (5) aktiv')
    case "$action" in
      1*) pick_scheme ;;
      2*) pick_mono ;;
      3*) pick_sans ;;
      4*) set_wallpaper; echo "→ Farben: aus Wallpaper generiert  (noch nicht angewandt)" ;;
      5*) apply ;;
      6*) discard ;;
      q*|'')
        if ! cmp -s "$STYLIX" "$BACKUP"; then
          echo
          echo "Hinweis: nicht-angewandte Änderungen liegen in stylix.nix."
          echo "  → beim nächsten 'fr' werden sie gebaut, oder starte theme-picker neu (5=Anwenden)."
        fi
        break ;;
    esac
  done
}

# ── Einstieg: Vorschau-Unterbefehle vor dem Menü abfangen ────────────────
case "${1:-}" in
  --scheme-preview) scheme_preview "${2:-}"; exit 0 ;;
  --font-preview)   font_preview "${2:-}"; exit 0 ;;
esac
main
