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

- `!`-Präfix: gilt nur im Claude-Prompt; im zsh-Terminal heisst `! befehl` «Ergebnis umkehren»
  und bricht `&&`-Ketten ab (passiert am 29.10. und 05.11.).
- Gerätenamen aus `lsblk` ablesen statt Platzhalter tippen (27.10.).

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
  → erledigt: Schalter selbst umgelegt (nvim, `:w`, `git diff` geprüft). Signal-Verlauf per
  `relogin` selbst geholt (29.10.).
- 2026-10-29: Charybdis-Firmware (RMK). User selbst: 10 neue Gerätenamen in `kanata.nix`
  eingetragen + `fr` (ohne Hinweis, **sitzt: Modul finden + Liste ergänzen**), beide Hälften
  per yazi geflasht (3×), in Vial Combos geleert und Prior-Idle gesetzt. Gute Rückfragen:
  „kopiert yazi beim `y` oder beim `p`?“ (Antwort: Pfad bei `y`, Inhalt bei `p`) und „gilt der
  Fix für alle Fälle?“ → deckte eine echte Lücke auf (zwei Mods auf verschiedenen Händen).
  Claude: RMK-Patch + Simulator-Tests, Wine-hidraw-Leck gefunden (`ls -l /proc/<pid>/fd`).
  Offene Übungsfrage: „BastardKB“ steht als Hersteller im USB-Namen – wo kommt das her?
- 2026-10-29: PAT420-Team-Anleitung (User: „du kannst loslegen“, Claude hat alles gebaut:
  `docs/anleitung/` im megger-tool, Markdown → pandoc → Word → PDF via LibreOffice). **Offene Übung (Stufe 1):**
  einen Satz in `anleitung.md` ändern (z. B. Namen eines Standorts) und `./bauen.sh` laufen
  lassen, dann im PDF nachschauen. Hinweis 1 genügt vermutlich. Übungsfrage: Warum liegt
  `bauen.sh` im Projekt und nicht in der NixOS-Config?
- 2026-10-29: PAT-Manager Teil 2 (Bearbeiten/Zurückspielen, neues Design, Fälligkeit, Mängel,
  QR-Etiketten) komplett von Claude gebaut (User: «mach a bis e»), 257 Tests, Version 0.2.0.
  Projekt liegt jetzt in `~/Dokumente/Technorama_Projekte/megger-tool`.
  **Offene Übung bleibt:** `naechste_pruefung()` in `pat_manager/faelligkeit.py` (Tests
  `tests/test_faelligkeit.py`, 4× xfail). Ohne sie zeigen Fällig-Seite und Kacheln «–».
  Hinweisstufe 2: Monat hochzählen, Jahr übertragen, Tag mit `calendar.monthrange` deckeln.
- 2026-10-29: Obsidian „📝 Neue Notiz“ (QuickAdd-Makro + JS-Skript `Vorlagen/Skripte/neue-notiz.js`,
  Claude gebaut). Knopf hat Claude eingebaut (User: "nächstes Mal"). Übung später nachholen: so einen Knopf/URL selbst bauen.
- 2026-10-29: Werdegang-Hook (Claude gebaut). Einbinden war für Claude gesperrt (Selbstveränderung),
  User führt es aus. Gelernt: `!`-Präfix gilt nur im Claude-Chat; in zsh heisst `!` „Ergebnis umkehren“.
- 2026-10-30: `naechste_pruefung()` hat Claude auf Wunsch geschrieben («warum kannst du diese
  Funktion nicht implementieren?») – die Übung war dem User nicht als solche präsent, die
  leere Fällig-Seite wirkte wie ein Fehler. Lehre: Lernaufgaben, die ein Feature blockieren,
  nicht offen lassen; lieber kleine, folgenlose Übungen (z. B. ein Test, eine Konstante).
  Übung aus Teil 2 damit zu; die Stufe-1-Übung an der Anleitung (`bauen.sh`) bleibt offen.
- 2026-11-02: Prüfkonzept (Dokument für den SiBe) hat Claude geschrieben, Megger-Ordner in
  `~/Dokumente/Technorama_Projekte/Elektropruefung_Exponate/` verschoben. **Offene Übung (Stufe 1–2):**
  der Launcher-Starter zeigt noch auf den alten Pfad; in `modules/meo/pat-manager.nix` die Zeile
  `projekt = …` auf den neuen Ordner ändern, `nh os build` zur Probe, dann `fr`. User: «mach du die Übung»
  → Claude hat den Pfad geändert; `fr` hat der User selbst ausgeführt (Launcher-Pfad, Technorama-Schriften, Grafik-Schriften aktiv).
- 2026-11-02: moOde-Radio (192.168.2.182). Mi-Soul spielte nicht, weil die TuneIn-Seite statt
  des Streams eingetragen war; Claude hat den Eintrag über die Web-Schnittstelle korrigiert, 29
  eigene Einträge mit Genre versehen und ~155 geprüfte Sender ergänzt (User: «leg du an»).
  SSH-Login (Benutzer `PI-999-EWS`) hat der User selbst getestet, Ausgang offen.
  **Offene Übung (Stufe 1):** einmal selbst einen Sender über die Radio-Ansicht anlegen
  (Stream-URL statt Webseite; Prüfung: Inhaltstyp `audio/mpeg` mit `curl -sI <url>`).
  Übungsfrage: Warum reicht die TuneIn-Adresse dem Player nicht?
- 2026-11-05: PAT-Manager auf GitHub (`Meo98/pat-manager`, privat). Vorbereitung (Commit,
  `main` nachziehen, Push von `main`, Standard-Branch) hat Claude gemacht; **User selbst:
  `gh repo create pat-manager --private --source=. --push`** (Hinweisstufe 3, Befehl erklärt).
  Erster Versuch mit `! cd … && gh …` im zsh-Terminal: `cd` lief, `gh` nicht (dasselbe wie am
  29.10., **wackelt: `!` gehört in den Claude-Prompt, nicht ins Terminal**). Zweiter Versuch sauber.
  Übungsfrage «Push angekommen, ohne Browser?» gestellt, Antwort gegeben: `git ls-remote --heads origin`.
  Nächste Übung in diesem Projekt: `git log --oneline origin/main -3` vs. lokal vergleichen.
- 2026-11-05 (abends): **User selbst, Hinweisstufe 3 (Befehle genannt), alles im ersten Anlauf und ohne
  `!`-Fehler:** `echo .git >> ~/Dokumente/.stignore` mit `cat`-Kontrolle; `gh repo create pat-daten
  --private --add-readme`; erster eigener kompletter Git-Zyklus `clone → cp → status → add → commit →
  push` im Daten-Repo; `git add docs/anleitung` + `commit` im Code-Repo. Verständnisfrage gestellt:
  «Was macht `git add`, wenn die Datei schon geändert ist?» (Staging). Kandidat für «Sitzt»: Git-Grundzyklus,
  sobald er es ein zweites Mal ohne Befehlsvorlage macht. Nächste Übung: `git checkout main && git merge
  feat/teil3` (Fast-Forward) und Push, danach `git log --oneline -3` auf beiden Branches vergleichen.
  Nachtrag Abend: moOde-Update 9.2.2 → 10.3.7 per neuem Image (Claude: Backup per API, Image auf
  /dev/mmcblk0 via run0/polkit, Auto-Restore-Zip). User selbst am Pi-Bildschirm: Erstbenutzer angelegt
  (Grossbuchstaben im Namen abgelehnt → `pi-999-ews`), `nmcli dev status` gelesen («wifi unavailable»),
  `rfkill unblock` + `nmcli dev wifi connect` getippt → Pi kam ins WLAN. **Sitzt: Konsolen-Login +
  nmcli nach Anleitung.** Ausgang: Pi kam nach ~20 min von selbst hoch, alles da.
- 2026-11-02: Craft Anything (ArtCraft) deklarativ ergänzt (Claude, auf Zuruf). Noch offen als
  kleine Übung: in `modules/meo/artcraft.nix` nachlesen, woher `mkCraft` Version und Hash holt
  (`versions.${pname}`), und mit `fr` aktivieren.
- 2026-11-03: `fr` scheiterte an Autostash-Konflikten (uncommittete Werdegang-Änderungen auf meo gegen
  neue Commits von meo-work). Claude hat aufgelöst (User: «mach du das»). **Wackelt: Konfliktmarker lesen
  und auflösen**, ähnliche Übung beim nächsten Konflikt nochmals geben.
  Offene Übungsfrage: Warum muss auch `hosts/meo-work/default.nix` sauber sein, wenn man auf meo baut?
- 2026-11-03: Technorama2050-Ordner aufgeräumt und Dokumente auf die Technorama-Vorlagen
  umgestellt (User: «kannst du …», also ohne Übung). Offene Mini-Aufgabe: Excel-Matrix in
  Excel öffnen und prüfen, ob das Logo in der Kopfzeile erscheint (Seitenlayout-Ansicht);
  Word-Datei in Word im Web öffnen (Bearbeitungsmodus muss gehen).
- 2026-11-05: Update-Warnung (`gtk2` als broken markiert) und voller Speicher auf meo-work. Claude hat
  `gtk2` aus der nix-ld-Liste entfernt und aufgeräumt (User: «A ist gut … kannst du alles machen»), ohne Übung.
  **Offene Mini-Aufgabe:** `fr` ausführen, danach einmal MPLAB in `/opt/microchip` starten, falls noch gebraucht.
  Übungsfrage: Warum gibt `nix-store --gc` erst nach dem Entfernen von `result` so viel Platz frei?
- 2026-11-05: Affinity und das zugehörige Wine aus der Config entfernt (`affinity-nix`-Input, Overlay, `enableAffinity`,
  Doku); ArtCraft ersetzt es. User hat den langen Update-Build selbst abgebrochen; Rest durch Claude auf Wunsch, ohne
  Übung. **Mini-Aufgabe:** `fr` im normalen Terminal ausführen (nicht `! fr`, dort kennt die Shell die Funktion nicht).
  User hat `fr` selbst ausgeführt, lief. Danach: RealVNC-RPM per `system.extraDependencies` vor der Garbage Collection geschützt.
- 2026-11-05: PAT420-Anleitung: Versionstabelle entfernt, Ablagepfad eingetragen, neu gebaut (Claude, User hat den
  Pfad direkt geliefert, ohne Übung). Die Stufe-1-Übung vom 29.10. (Satz in `anleitung.md` ändern, `./bauen.sh`) bleibt offen.
  Danach Frage zu WordCraft: Tabellenzeilen im Prüfkonzept liessen sich «nicht löschen» (Entf leert nur den Inhalt, wie in
  Word). **Mini-Aufgabe gegeben:** die 38 leeren Zeilen selbst markieren und mit Rücktaste bzw. «Delete Rows» entfernen. Ausgang offen.
- 2026-11-05: Casambi-Projekt wieder aufgenommen (viel Fragen/Antworten zu Gateways, DALI, Home Assistant).
  `casambi-bt` als Projekt-Umgebung eingerichtet (`Casambi/Auslesen/flake.nix`, Claude, User: «installiere mal»).
  **Mini-Aufgabe (Stufe 1):** bei den Leuchten selbst `nix develop` und `python suchen.py` ausführen und die
  Ausgabe mitbringen. Erste Begegnung mit `nix develop` (Umgebung pro Projekt statt Paket im System).
  Übungsfrage: Warum steht `casambi-bt` in einer `flake.nix` im Projektordner und nicht in `host-packages.nix`?
- 2026-11-05: SEW-Login gesperrt («NOT_ALLOWED_TO_ACCESS»). Claude hielt Tailscale zuerst für unschuldig;
  **User hat selbst mit `sudo tailscale down` / `up` getestet und Claude widerlegt** (Ursache: NextDNS-Filter
  über Tailscale-DNS). **Mini-Aufgabe (Stufe 1):** im NextDNS-Protokoll den gesperrten Namen finden und auf die
  Zulassungsliste setzen. Übungsfrage: Warum ändert sich die öffentliche Adresse bei `tailscale down` nicht?
- 2026-11-09: DMS-Workspace-Anzeige pro Monitor (meo): Ursache `workspaceFollowFocus=true`
  (Claude gefunden). User hat die Option selbst in der DMS-Oberfläche gefunden und
  ausgeschaltet, mit Hinweis 1–2. Verständnisfrage «warum hilft Umschalten auf meo-work
  nicht?» (settings.json gehört DMS, pro Host, nicht im Repo) unbeantwortet.
