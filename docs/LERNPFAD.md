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
- 2026-10-27: Megger PAT420 (Prüfgerät, Display defekt = Hardware). User hat USB-Stick in
  yazi gesucht und mkfs per `:`-Shell versucht; Fehler: Platzhalter `/dev/sdX1` wörtlich
  getippt → **wackelt: Gerätenamen aus `lsblk` ablesen**. Formatieren hat Claude per udisks
  gemacht. Projekt `~/Dokumente/Technorama_Projekte/megger-tool` (PAT-Manager, Python+Qt) von Claude gebaut, Teil 1 fertig.
  **Offene Übung (Python, Stufe 5 vorgezogen):** `naechste_pruefung()` in
  `pat_manager/faelligkeit.py` selber schreiben (Tests in `tests/test_faelligkeit.py`).
- 2026-10-28: Matrix-Probelauf (Synapse + Signal-Brücke, `modules/meo/matrix.nix`, Claude gebaut).
  User selbst: Tailscale-HTTPS in der Admin-Konsole, `fr`, Konto per `register_new_matrix_user`,
  Element-Login, Signal-Verknüpfung inkl. Fehlersuche am Handy (VPN/Daten/App-Version ausgeschlossen).
  Offene Übung: api_id/api_hash von my.telegram.org holen, `telegramBereit` selbst umschalten.
- 2026-10-29: Charybdis-Firmware (RMK). User selbst: 10 neue Gerätenamen in `kanata.nix`
  eingetragen + `fr` (ohne Hinweis, **sitzt: Modul finden + Liste ergänzen**), beide Hälften
  per yazi geflasht (3×), in Vial Combos geleert und Prior-Idle gesetzt. Gute Rückfragen:
  „kopiert yazi beim `y` oder beim `p`?“ (Antwort: Pfad bei `y`, Inhalt bei `p`) und „gilt der
  Fix für alle Fälle?“ → deckte eine echte Lücke auf (zwei Mods auf verschiedenen Händen).
  Claude: RMK-Patch + Simulator-Tests, Wine-hidraw-Leck gefunden (`ls -l /proc/<pid>/fd`).
  Offene Übungsfrage: „BastardKB“ steht als Hersteller im USB-Namen – wo kommt das her?
- 2026-10-29: PAT420-Team-Anleitung (User: „du kannst loslegen“, Claude hat alles gebaut:
  `docs/anleitung/` im megger-tool, Markdown → pandoc → weasyprint). **Offene Übung (Stufe 1):**
  einen Satz in `anleitung.md` ändern (z. B. Namen eines Standorts) und `./bauen.sh` laufen
  lassen, dann im PDF nachschauen. Hinweis 1 genügt vermutlich. Übungsfrage: Warum liegt
  `bauen.sh` im Projekt und nicht in der NixOS-Config?
- 2026-10-29: PAT-Manager Teil 2 (Bearbeiten/Zurückspielen, neues Design, Fälligkeit, Mängel,
  QR-Etiketten) komplett von Claude gebaut (User: «mach a bis e»), 257 Tests, Version 0.2.0.
  Projekt liegt jetzt in `~/Dokumente/Technorama_Projekte/megger-tool`.
  **Offene Übung bleibt:** `naechste_pruefung()` in `pat_manager/faelligkeit.py` (Tests
  `tests/test_faelligkeit.py`, 4× xfail). Ohne sie zeigen Fällig-Seite und Kacheln «–».
  Hinweisstufe 2: Monat hochzählen, Jahr übertragen, Tag mit `calendar.monthrange` deckeln.
- 2026-10-30: `naechste_pruefung()` hat Claude auf Wunsch geschrieben («warum kannst du diese
  Funktion nicht implementieren?») – die Übung war dem User nicht als solche präsent, die
  leere Fällig-Seite wirkte wie ein Fehler. Lehre: Lernaufgaben, die ein Feature blockieren,
  nicht offen lassen; lieber kleine, folgenlose Übungen (z. B. ein Test, eine Konstante).
  Übung aus Teil 2 damit zu; die Stufe-1-Übung an der Anleitung (`bauen.sh`) bleibt offen.
