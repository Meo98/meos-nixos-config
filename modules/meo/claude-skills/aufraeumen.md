---
name: aufraeumen
description: Den Notizen-Eingang (~/Notizen/Eingang) einsortieren – Titel vergeben, Projektnotizen ergänzen, Rest an den richtigen Ort verschieben. Nutze diesen Skill bei "/aufräumen", "räum die Notizen auf", "sortier den Eingang", oder wenn im Eingang mehr als etwa 10 Notizen liegen und der User an Notizen arbeitet.
---

# Notizen-Eingang aufräumen

Der User schreibt alles Neue ohne Nachdenken nach `~/Notizen/Eingang/` (oft am Handy, oft ohne Titel).
Du sortierst. Regeln der Struktur: `~/Notizen/Lies mich.md`.

## Ablauf

1. Alle Dateien in `~/Notizen/Eingang/` lesen.
2. Jede Notiz einem Ziel zuordnen:

| Inhalt | Ziel | Was du tust |
|---|---|---|
| gehört zu einem bestehenden Projekt | `Projekte/<Bereich>/<Projekt>.md` | Inhalt sinnvoll einarbeiten (Verlauf mit Datum der Notiz, Nächste Schritte oder Erkenntnisse), Eingangsdatei danach löschen |
| neues Projekt | `Projekte/<Bereich>/` | aus `.vorlagen/Projekt.md` anlegen – vorher fragen |
| Gedanken, Gefühle, Tagebuch, Diskussion | `Persönlich/Gedanken/` | **nur verschieben**, Inhalt nicht verändern; fehlt ein Titel, Dateinamen vergeben |
| eigener Text, Liedtext | `Persönlich/Texte & Lieder/` | nur verschieben, Dateinamen vergeben |
| wiederverwendbares Wissen | `Wissen/<Thema>.md` | in bestehende Themen-Datei einarbeiten oder neue anlegen |
| Kurioses, unnützes Wissen | `Wissen/Fundgrube.md` | als Stichpunkt anhängen |
| unklar | – | in der Liste am Ende fragen, nicht raten |

3. Dateinamen: kurz, beschreibend, Wörter mit Bindestrich, Datum vorn nur bei Tagebuch-artigem
   (`2026-10-28 Gedanken zu …`). Die erste Zeile ist oft ein guter Titel.

## Regeln

- Inhalte aus `Persönlich/` nie umschreiben, zusammenfassen oder weiterverwenden – nur ablegen.
  Bestehende Dateien in `Persönlich/` nicht öffnen, ausser zum Vermeiden von Namenskonflikten.
- Nichts endgültig löschen, was nicht vollständig in eine andere Notiz eingearbeitet wurde.
- Vor jeder Änderung die Zieldatei neu lesen (Syncthing, Handy).
- Bei Projektnotizen die Regeln des Skills `notiz` einhalten (kurz, keine Befehlslisten, Übersicht nachführen).
- Am Ende eine kurze Tabelle: Notiz → wohin. Danach die offenen Fragen zu unklaren Notizen in einer Liste.
