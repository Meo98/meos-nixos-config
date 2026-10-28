---
name: notiz
description: Projektnotiz in ~/Notizen nachführen – Verlauf, Stand, nächste Schritte. Nutze diesen Skill bei "/notiz", "schreib das in die Notizen", "trag das ins Projekt ein", und von dir aus am Ende jeder Arbeitssitzung, in der an einem Projekt etwas Nennenswertes passiert ist (gebaut, entschieden, herausgefunden, bestellt, gedruckt).
---

# Projektnotiz nachführen

Die Notizen des Users liegen in `~/Notizen` (Regeln: `~/Notizen/Lies mich.md`). Jedes Projekt hat genau eine
Datei unter `~/Notizen/Projekte/<Bereich>/`. Du hältst sie aktuell, damit der User nie selbst nachtragen muss.

## 1. Richtige Notiz finden

- Über die Frontmatter-Zeile `ordner:`: `grep -rl "^ordner: <pfad>" ~/Notizen/Projekte` mit dem aktuellen
  Arbeitsverzeichnis bzw. dem Projektordner, an dem gearbeitet wurde (auch Unterordner zählen).
- Sonst über den Namen (`ls ~/Notizen/Projekte/*/`).
- Kein Treffer: kurz fragen, ob eine neue Notiz angelegt werden soll und in welchem Bereich
  (Privat, Printbrigata, Technorama, Espace). Neue Notizen immer aus `~/Notizen/.vorlagen/Projekt.md`.

## 2. Aktualisieren

Datei **direkt vor dem Schreiben neu lesen** (der User kann sie am Handy geändert haben, Syncthing).

- **Verlauf**: eine neue Zeile ganz oben, `- JJJJ-MM-TT: <was passiert ist, ein Satz>`. Pro Tag höchstens
  eine Zeile; gibt es heute schon eine, diese ergänzen.
- **Stand**: neu schreiben, falls er nicht mehr stimmt (3–5 Zeilen).
- **Nächste Schritte**: Erledigtes abhaken (`- [x]`) bzw. nach ein paar Tagen entfernen, Neues ergänzen.
- **Wichtige Erkenntnisse**: nur, wenn etwas herausgefunden wurde, das man nicht noch einmal suchen will.
  Kurz und menschenlesbar, keine Befehlslisten (Details gehören ins Repo bzw. in die Claude-Memory).
- Frontmatter: `zuletzt:` auf heute, `status:` anpassen, falls sich das geändert hat.
- `~/Notizen/Übersicht.md`: die Zeile dieses Projekts (Stand, nächster Schritt, zuletzt) angleichen.
- Wurde am Schaltplan (`.kicad_sch`) gearbeitet: `notizen-bom` ausführen. Es schreibt den Abschnitt
  `## Stückliste` (zwischen `<!-- notizen-bom:start/end -->`) und `Wissen/Bauteile.md` neu – diese Teile
  nie von Hand bearbeiten. Bauteil-Wissen gehört in eine eigene Notiz `Wissen/<Bauteil>.md`.

## Regeln

- Kurz halten: eine Projektnotiz soll in einer Minute lesbar sein. Lieber kürzen als anhängen.
- Dateien (CAD, Bilder, Code, Tabellen) nie in die Notizen kopieren, nur Pfade verlinken.
- Keine Passwörter, Tokens, API-Keys.
- `~/Notizen/Persönlich/` nie anfassen, ausser der User verlangt es ausdrücklich.
- Am Ende in einer Zeile sagen, welche Notiz du wie geändert hast.
