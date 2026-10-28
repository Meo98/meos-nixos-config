---
name: verknuepfen
description: Notizen in ~/Notizen taggen und miteinander verlinken (Netz knüpfen). Nutze diesen Skill bei "verknüpfe die Notizen", "tagge das", "/verknuepfen", nach dem Aufräumen des Eingangs und beim wöchentlichen Notizen-Lauf – für neue oder seit dem letzten Lauf geänderte Notizen.
---

# Notizen verknüpfen

Struktur, die FESTE Tag-Liste und die Regeln stehen in `~/Notizen/Lies mich.md` – zuerst lesen.

## Was du tust (pro Notiz)

1. **Tags**: im Frontmatter `tags:` 1–3 Tags aus der Liste in `Lies mich.md` (YAML-Liste ohne `#`).
   Keine anderen Tags. Passt keiner: keinen setzen. Fehlt Frontmatter, oben anlegen.
2. **Links**: 0–5 wirklich sinnvolle Verbindungen zu anderen Notizen (gleiches Projekt, Bauteil, Person,
   Ereignis, Fortsetzung eines Gedankens, Text ↔ Anlass, Projekt ↔ Wissen). Lieber keine als schwache.
   - Projektnotizen: in passenden Abschnitten oder in `## Verwandt` (direkt vor `## Verlauf`,
     `- [[Notiz]] – Grund`).
   - Alle anderen: am Ende ein Block `---` + `Verwandt: [[A]] · [[B]]`; vorhandenen Block ergänzen.
   - Ziel = exakter Dateiname ohne `.md`; Existenz prüfen.
3. Eine Notiz, auf die du verlinkst, bekommt nicht automatisch einen Rücklink – Obsidian zeigt
   Rückverweise selbst an.

## Regeln

- `Persönlich/`: lesen und verknüpfen ist erlaubt, Inhalt NIE verändern, zusammenfassen oder zitieren –
  nur `tags`, der Verwandt-Block und der Ablageort (Tagebuch-artiges nach `Persönlich/Tagebuch/`).
- Nicht anfassen: `Vorlagen/`, `Start.md`, `Wissen/Bauteile.md`, Abschnitte zwischen
  `<!-- notizen-bom:start -->` und `<!-- notizen-bom:end -->`.
- Datei direkt vor dem Schreiben neu lesen (Syncthing). Nichts löschen.
- Am Ende prüfen: keine Tags ausserhalb der Liste, keine Links ins Leere.
