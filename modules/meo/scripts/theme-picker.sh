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

# ── Vorschau: Schrift als BILD in ihrer echten Gestalt rendern ───────────
# Zeile = Display|nixAttr|fontconfigFamily|regulaereDatei . Die reguläre
# Schnittdatei wird in $THEME_PICKER_FONTS_DIR (symlinkJoin aller Fonts)
# gesucht, mit magick in den echten Glyphen gesetzt und via chafa als
# Terminalblöcke gezeigt. Fallback = Text, falls magick/chafa/Datei fehlt.
font_preview() {
  local row="$1" disp attr fam base file MG cols sample
  disp=$(printf '%s' "$row" | awk -F'|' '{print $1}')
  attr=$(printf '%s' "$row" | awk -F'|' '{print $2}')
  fam=$(printf  '%s' "$row" | awk -F'|' '{print $3}')
  base=$(printf '%s' "$row" | awk -F'|' '{print $4}')
  printf '  \033[1m%s\033[0m\n  pkgs.%s   ("%s")\n\n' "$disp" "$attr" "$fam"

  file=""
  [ -n "${THEME_PICKER_FONTS_DIR:-}" ] && [ -n "$base" ] && \
    file=$(find "$THEME_PICKER_FONTS_DIR" -name "$base" 2>/dev/null | head -1)
  MG=""
  command -v magick  >/dev/null 2>&1 && MG=magick
  [ -z "$MG" ] && command -v convert >/dev/null 2>&1 && MG=convert

  if [ -n "$file" ] && [ -n "$MG" ] && command -v chafa >/dev/null 2>&1; then
    cols=${FZF_PREVIEW_COLUMNS:-56}; [ "$cols" -gt 74 ] && cols=74
    case "$attr" in
      nerd-fonts.*) sample=$'AaBbCcDdEeFf 0123456789\nfn main() { x != y => ok }\n== != >= <= -> => :: |> </>' ;;
      *)            sample=$'The quick brown fox jumps\nover the lazy dog  0123456789\nAa Bb Cc Dd Ee Ff Gg Hh Ii' ;;
    esac
    # IM v7: label: muss VOR -border stehen (border ist eine Bild-Operation).
    "$MG" -background "#12141c" -fill "#e6e6e6" -font "$file" -pointsize 40 \
        label:"$sample" -bordercolor "#12141c" -border 12 png:- 2>/dev/null \
      | chafa --size "${cols}x16" --format symbols - 2>/dev/null \
      || printf '  (Bild-Render fehlgeschlagen — Auswahl wird trotzdem gesetzt)\n'
  else
    printf '  Pangram: The quick brown fox jumps over the lazy dog\n'
    printf '  0123456789  {}[]()<>/=+-*_   != == => ->\n\n'
    printf '  (Bild-Vorschau nicht verfügbar — magick/chafa/Datei fehlt)\n'
  fi
}

# ── stylix.nix: Zeile zwischen zwei Markern ersetzen ─────────────────────
replace_block() {
  # $1 Begin-Marker, $2 End-Marker, $3 Ersatztext (mehrzeilig erlaubt, muss
  # eigene \n enthalten; leer = Bereich leeren). Ersatz über ENVIRON statt
  # awk -v, damit Zeilenumbrüche & Sonderzeichen unverändert durchlaufen.
  local b="$1" e="$2"
  REPL="$3" awk -v b="$b" -v e="$e" '
    index($0,b){print; printf "%s", ENVIRON["REPL"]; inb=1; next}
    index($0,e){inb=0; print; next}
    inb{next}
    {print}
  ' "$STYLIX" > "$STYLIX.tmp" && mv "$STYLIX.tmp" "$STYLIX"
}

set_scheme() {
  # WICHTIG: als base16-Attrset schreiben (base00..base0F), NICHT als Pfad!
  # zaneyos-Module (rofi/waybar) lesen config.stylix.base16Scheme.baseXX direkt
  # -> muss ein Set sein, sonst "expected a set but found a string".
  # Scheme-Name als Kommentar davor, damit current_scheme() ihn wiederfindet.
  local sel="$1" f="$SCHEMES_DIR/$1.yaml" i hex block
  block="    # theme-picker: $sel"$'\n'"    base16Scheme = {"$'\n'
  for i in 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F; do
    hex=$(grep -iE "base$i:" "$f" | grep -oiE '[0-9a-f]{6}' | head -1 | tr 'A-F' 'a-f')
    block="$block      base$i = \"$hex\";"$'\n'
  done
  block="$block    };"$'\n'
  replace_block "THEME_PICKER_SCHEME_BEGIN" "THEME_PICKER_SCHEME_END" "$block"
}
set_wallpaper() {
  replace_block "THEME_PICKER_SCHEME_BEGIN" "THEME_PICKER_SCHEME_END" ""
}
set_mono() {
  replace_block "THEME_PICKER_MONO_BEGIN" "THEME_PICKER_MONO_END" \
    "      monospace = { package = pkgs.$1; name = \"$2\"; };"$'\n'
}
set_sans() {
  replace_block "THEME_PICKER_SANS_BEGIN" "THEME_PICKER_SANS_END" \
    "      sansSerif = { package = pkgs.$1; name = \"$2\"; };"$'\n'
}

# ── aktuellen Stand aus der Datei lesen (für die Menü-Anzeige) ───────────
current_scheme() {
  local l
  l=$(awk '/THEME_PICKER_SCHEME_BEGIN/{f=1;next} /THEME_PICKER_SCHEME_END/{f=0} f' \
        "$STYLIX" | sed -n 's/^[[:space:]]*# theme-picker: //p' | head -1)
  if [ -z "$l" ]; then echo "Wallpaper-Palette"; else printf '%s\n' "$l"; fi
}
current_font() { # $1 = MONO|SANS
  awk -v b="THEME_PICKER_$1_BEGIN" -v e="THEME_PICKER_$1_END" \
    'index($0,b){f=1;next} index($0,e){f=0} f' "$STYLIX" \
    | grep -oE 'name = "[^"]*"' | sed 's/name = "//; s/"$//'
}

# ── Font-Kataloge (Display|nixAttr|fontconfigName) ───────────────────────
# Format: Display|nixAttr|fontconfigFamily|regulaereSchnittdatei
# (Family + Datei autoritativ per fc-scan ermittelt; Family = das, was
# fontconfig nach dem Rebuild kennt, Datei = für die Bild-Vorschau.)
mono_list() {
  printf '%s\n' \
    'JetBrains Mono|nerd-fonts.jetbrains-mono|JetBrainsMono Nerd Font Mono|JetBrainsMonoNerdFontMono-Regular.ttf' \
    'FiraCode|nerd-fonts.fira-code|FiraCode Nerd Font Mono|FiraCodeNerdFontMono-Regular.ttf' \
    'Hack|nerd-fonts.hack|Hack Nerd Font Mono|HackNerdFontMono-Regular.ttf' \
    'Iosevka|nerd-fonts.iosevka|Iosevka Nerd Font|IosevkaNerdFont-Regular.ttf' \
    'MesloLGS|nerd-fonts.meslo-lg|MesloLGSDZ Nerd Font Mono|MesloLGSDZNerdFontMono-Regular.ttf' \
    'CaskaydiaCove (Cascadia)|nerd-fonts.caskaydia-cove|CaskaydiaCove Nerd Font Mono|CaskaydiaCoveNerdFontMono-Regular.ttf' \
    'SauceCodePro (Source)|nerd-fonts.sauce-code-pro|SauceCodePro Nerd Font|SauceCodeProNerdFont-Regular.ttf' \
    'CommitMono|nerd-fonts.commit-mono|CommitMono Nerd Font Mono|CommitMonoNerdFontMono-Regular.otf' \
    'GeistMono|nerd-fonts.geist-mono|GeistMono Nerd Font Mono|GeistMonoNerdFontMono-Regular.otf'
}
sans_list() {
  # Nur metrik-sichere Fonts: breite Fonts (z.B. Montserrat) sprengen
  # hartkodierte Qt/GTK-Dialogbreiten (siehe Kommentar in stylix.nix).
  printf '%s\n' \
    'Noto Sans (Standard)|noto-fonts|Noto Sans|NotoSans.ttf' \
    'Inter|inter|Inter Variable|InterVariable.ttf' \
    'DejaVu Sans|dejavu_fonts|DejaVu Sans|DejaVuSans.ttf' \
    'Cantarell|cantarell-fonts|Cantarell|Cantarell-VF.otf' \
    'Fira Sans|fira|Fira Sans|FiraSans-Regular.ttf' \
    'Roboto|roboto|Roboto|Roboto-Regular.ttf' \
    'Work Sans|work-sans|Work Sans|WorkSans-Regular.ttf' \
    'Ubuntu|ubuntu-classic|Ubuntu|Ubuntu-R.ttf' \
    'Source Sans|source-sans|Source Sans 3|SourceSans3-Regular.ttf'
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
