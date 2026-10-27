# Lernpfad

Fortschritt für den Lernmodus (siehe `modules/meo/claude-global.md`).
Claude liest das zu Beginn und trägt nach Sessions nach. Selber editieren erlaubt.

## Aktuelle Stufe: 1 – Orientierung

## Stufen (grob, nicht starr)

1. **Orientierung**: Dateien finden (`rg`, `fd`, `ls`), `git diff/status/log`,
   `fr` verstehen, Paket hinzufügen, Option nachschlagen (search.nixos.org).
2. **Config selbst ändern**: Home-Manager-Optionen setzen, Module lesen,
   Build-Fehler lesen und deuten, Rollback (`nixos-rebuild --rollback`, Bootmenü).
3. **Nix verstehen**: `let … in`, Funktionen, `lib.mkIf`, `mkOption`, Overlays,
   `nix repl`, eigenes kleines Modul schreiben.
4. **System-Debugging**: `journalctl`, `systemctl --user`, Prozesse, Logs,
   eigene Skripte (Bash), erste Automationen.
5. **Programmieren**: kleine Tools in Rust oder Python, selbst paketieren (`buildRustPackage`).

## Sitzt

- (noch nichts eingetragen)

## Wackelt / üben

- (noch nichts eingetragen)

## Log

- 2026-10-22: Lernmodus eingeführt.
- 2026-10-23: Aufgabe "Änderung mit `fr` live bringen" selbständig gelöst (ohne Hinweis).
  Offen: herausfinden, wo `_zsync` definiert ist und wie es neue Dateien mitnimmt
  (Doku in CLAUDE.md sagt `commit -am`, stimmt offenbar nicht).
- 2026-10-23: Tilde ging in Ghostty nicht (GTK 4.20 + niri verschluckt Tottasten).
  Eingegrenzt per Test Browser vs. Terminal (User). Fix `de_nodeadkeys` hat Claude gemacht
  (User: "zu mühsam gerade"). Später als Übung: `rg`, `let … in`, `or`-Default nochmals.
- 2026-10-26: `fu` scheiterte (3 Fehler nacheinander: fastmcp-slim broken, RealVNC-RPM
  weg-gegarbage-collected, doppeltes Hyprland-Portal). Claude hat gefixt (User: "einfach
  schnell lösen"). Gelernt: Rollback von `fu` schützt; Nix-Fehler von unten lesen.
  Offene Übung: Fehlerausgabe selbst lesen (welches Paket, welche eigene Datei).
- 2026-10-27: Syncthing in `modules/upstream/core/syncthing.nix` eingeschaltet (Claude,
  User: "setz du"). Übungsfrage "was heisst `upstream/core` für die Hosts?" offen geblieben.
  Sicherheits-Gespräch: Verständnisfrage "warum schützt der read-only Store nicht vor
  fremdem Git-Zugriff?" **richtig beantwortet** (fr → git pull holt fremden Code).
  `_zincoming` (fr/fu zeigen eingehende Commits, fremde Autoren → Rückfrage) hat Claude
  gebaut (User: "mach du"). Übung später: Funktion lesen + erklären (`HEAD..@{u}`, `grep -vF`).
