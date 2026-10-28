# Globaler Kontext für Claude Code auf diesem System

Diese Datei wird von home-manager aus `~/nixos-config/modules/meo/claude-global.md`
nach `~/.claude/CLAUDE.md` verlinkt. Änderungen dort im Repo machen.

## System

- **NixOS**, Flake in `~/nixos-config` (GitHub: Meo98/meos-nixos-config). Zwei Hosts:
  `meo` (privat, NVIDIA-Laptop) und `meo-work` (Arbeit, Intel iGPU). Hostname: `hostname`.
- Desktop: **niri** (Wayland), Shell **zsh**, Home Manager ist in den Flake integriert.
- Sprache des Users: Deutsch (Schweiz). Antworte auf Deutsch, Code-Kommentare auf Deutsch.

## Regel Nr. 1: deklarativ, nicht imperativ

Alles, was dauerhaft sein soll, gehört in die Config, nicht ins laufende System:

- **Kein** `nix-env -i`, **kein** `nix profile install` für dauerhafte Tools.
  Pakete kommen in `hosts/<host>/host-packages.nix` (pro Host) bzw.
  `modules/upstream/core/packages.nix` (beide Hosts).
- **Keine** Dateien in `~/.config/` von Hand editieren, wenn Home Manager sie
  verwaltet (Symlink nach `/nix/store` = verwaltet). Dann das zugehörige
  Modul in `modules/meo/` oder `modules/upstream/home/` ändern.
- `nix shell nixpkgs#foo` / `nix run` sind fürs Ausprobieren okay.
- Ausnahme: Claude-Code-Plugins und -Marketplaces werden bewusst imperativ in
  `~/.claude/` gepflegt (siehe `modules/meo/claude-code.nix`).

## Bauen und aktivieren

- Prüfen ohne aktivieren: `nh os build --hostname <host>` (im Repo).
- Aktivieren: `fr` (Alias). Macht `git pull`, auto-commit **aller** dirty Dateien,
  `git push`, dann `nh os switch`. Also: nur fertige Änderungen im Repo lassen.
- `nh os switch` braucht sudo. Aus einer Claude-Session heraus geht das nicht
  interaktiv; dem User `fr` oder `! fr` vorschlagen.
- Vor einem Push beide Hosts dry-builden (`--hostname meo` **und** `--hostname meo-work`).
- Details, Gotchas, Troubleshooting: `~/nixos-config/CLAUDE.md` und `docs/`.

## Lernmodus (Standard bei gemeinsamen Projekten)

Der User will nicht daneben sitzen, sondern Linux, NixOS, Nix, Shell, Git und
später Rust/Python selber lernen, schleichend, über lange Zeit. Daher:

- **Lernstand lesen**: Zu Beginn jeder Aufgabe `~/nixos-config/docs/LERNPFAD.md`
  lesen (Stufe, was sitzt, was noch wackelt). Nach einer Session dort kurz
  nachtragen, was der User selber gemacht hat und wie es lief.
- **Delegieren statt erledigen**: Pro Aufgabe 1–3 Schritte heraussuchen, die zur
  aktuellen Stufe passen, und dem User geben. Den Rest (Boilerplate, langes
  Debugging, riskante Ops) selber machen.
- **Hinweise eskalieren** (wenig sagen, nachlegen wenn nötig):
  1. Nur das Ziel ("Finde heraus, welches Modul die Bar konfiguriert.")
  2. Richtung ("Schau mit `rg` in `modules/`.")
  3. Konkreter Befehl / Codegerüst
  4. Lösung vormachen und erklären
  Erst zur nächsten Stufe, wenn der User fragt oder klar feststeckt.
- **Schwierigkeit anpassen**: Klappt etwas zweimal ohne Hilfe → in LERNPFAD.md
  als "sitzt" markieren und nächstes Mal schwerer. Braucht er Hinweis 3–4 →
  ähnliche Aufgabe später nochmals geben.
- **Nebenbei Sprachen einstreuen**: Ab und zu ein kleines Stück Nix (Funktion,
  `let … in`, `lib.mkIf`), später Bash-Skripte, dann Rust/Python, wenn es
  natürlich passt. Nie als Lektion, immer am echten Problem.
- **Prüfen statt abnicken**: Nach einem User-Schritt kurz verifizieren
  (Ergebnis anschauen) und eine Verständnisfrage stellen, wenn es sich lohnt.
- **Ausnahmen**: Sagt der User "mach du", "keine Zeit" oder ist etwas dringend
  kaputt (Boot, Netz, Arbeit blockiert) → normal selber erledigen, ohne Übung.
- Nicht jede Antwort zur Übung machen. Faustregel: etwa eine echte
  Mitmach-Aufgabe pro Session, Fragen nur beantworten bleibt erlaubt.

## Nix-Fakten nachschlagen statt raten

Der MCP-Server **mcp-nixos** ist aktiv (Tools `nix`, `nix_versions`). Bei
Paketnamen, Optionsnamen, Home-Manager-Optionen oder "seit welcher nixpkgs-Version
gibt es X" immer dort nachschlagen, bevor etwas in die Config geschrieben wird.
Er kennt die konkrete Config hier nicht; für lokale Werte `nix eval` verwenden,
z. B. `nix eval ~/nixos-config#nixosConfigurations.meo-work.config.<option>`.

## Notizen (`~/Notizen`)

Der User führt seine Notizen als Markdown in `~/Notizen` (Syncthing auf meo, meo-work, Handy;
Struktur und Regeln in `~/Notizen/Lies mich.md`). Jedes Projekt hat genau eine Datei unter
`~/Notizen/Projekte/<Privat|Printbrigata|Technorama|Espace>/`, gefunden über die Frontmatter-Zeile `ordner:`.

- **Nach Arbeit an einem Projekt** (etwas gebaut, entschieden, herausgefunden): am Ende der Sitzung die
  Projektnotiz mit dem Skill `notiz` nachführen, ohne dass der User darum bittet. Bei reinen Fragen nicht.
- **Eingang aufräumen** mit dem Skill `aufraeumen`, wenn der User es sagt oder der Eingang voll ist.
- **Tags und Links** mit dem Skill `verknuepfen` (feste Tag-Liste in `Lies mich.md`, keine anderen Tags).
- `~/Notizen/Persönlich/` darf zum Ordnen und Verknüpfen gelesen werden, der Inhalt wird nie verändert,
  zusammengefasst oder zitiert.
- Wöchentlich (So 18:00, nur meo) läuft `notizen-woche` headless: Eingang aufräumen, verknüpfen,
  notizen-bom, Wochenbericht in den Eingang.
- Dateien nie in die Notizen kopieren, nur verlinken. Notizen kurz halten.
