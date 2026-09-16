# Ghostty: Scroll-Fixes fuer upstream

Vorbereitet 2026-09-16 gegen `ghostty-org/ghostty` `main` (d4c88d8).
Branch lag in `.../scratchpad/ghostty`, Commits `e4fafe4` und `5711a3b`.

**Noch nicht eingereicht.** Warum nicht, steht unten unter „Vouch".

## Ausgangslage

`modules/meo/ghostty-scroll-fix.nix` patcht drei Fehler in `scrollCallback()`.
Stand 2026-09-16:

| Befund | Status upstream |
|---|---|
| 1. Klemmung `@max(yoff, 1)` trifft auch Linux | **behoben** — PR #12483, gemergt 2026-04-27, mit derselben Loesung (macOS-Gate) |
| 2. Sub-Zeilen-Rest wird verworfen | offen in `main`, kein PR |
| 3. x-Achse rundet Hi-Res-Ticks auf null | offen in `main`, kein PR |

v1.3.1 ist vom **2026-03-13** und seit einem halben Jahr der neueste Tag.
Der Fix fuer Befund 1 kam sechs Wochen nach dem Release. Deshalb braucht
unser Overlay ihn weiterhin, obwohl upstream ihn hat
(`compare/154169b0...v1.3.1` → `ahead=0, behind=862`).

Die beiden Patches hier enthalten **nur Befund 2 und 3**.

## Befund 2 — der Akkumulator wird jedes Mal genullt

```zig
const amount = poff / cell_size;                     // f64, z.B. 1.7
self.mouse.pending_scroll_y = poff - (amount * cell_size);
const delta: isize = @intFromFloat(@trunc(amount));  // scrollt 1 Zeile
```

`poff` sind die aufgelaufenen Pixel. Gescrollt wird `delta` = 1 Zeile, also
`1 * cell_size` Pixel. Uebrig bleiben muesste `poff - 1 * cell_size`, das
sind 0,7 Zeilen.

Der Code zieht aber `amount * cell_size` ab. Und weil `amount` ein Float ist,
ist `amount * cell_size` wieder exakt `poff` — die Subtraktion ergibt **null**.
Die 0,7 Zeilen sind weg.

Der Code sieht aus, als fuehre er einen Akkumulator; er setzt ihn nur jedes
Mal zurueck. Beim Lesen faellt das nicht auf, erst beim Nachrechnen.

Verlust waechst mit dem Tempo: beim Lesen unter 1 %, beim schnellen Rollen
rund 20 %, und der Zeilentakt wird ungleichmaessig.

**Fix:** das *gerundete* `delta` abziehen statt `amount`.

## Befund 3 — horizontale Hi-Res-Ticks landen bei null

```zig
if (!scroll_mods.precision) {
    const x_delta_isize: isize = @intFromFloat(@round(xoff));
    break :x .{ .delta = x_delta_isize };            // kein Akkumulator
}
```

Im Nicht-Praezisions-Pfad ist `xoff` eine Anzahl Wheel-Ticks, keine Pixel.
Ein Hi-Res-Tick meldet einen Bruchteil eines Klicks, z.B. 0,25.
`@round(0,25)` ist 0 — das Event wird ersatzlos verworfen, und weil es den
Akkumulator gar nicht erst erreicht, kann sich auch nichts aufsummieren.
Auf Geraeten mit `REL_WHEEL_HI_RES` (Wayland: `wl_pointer.axis_value120`)
ist horizontales Scrollen damit praktisch tot.

Die y-Achse macht es an derselben Stelle richtig: Ticks erst in Pixel
umrechnen (`tick * cell_size * multiplier.discrete`), dann durch den
Akkumulator.

**Fix:** x genauso behandeln wie y.

Bewusst **nicht** mitgeaendert: der Praezisions-Pfad von x ignoriert
`mouse-scroll-multiplier.precision`, anders als y. Sieht inkonsistent aus,
aber eine Aenderung wuerde bestehendes Verhalten verschieben — gehoert in
einen eigenen PR, nicht in einen Bugfix.

## Pruefung

Voll gebaut wurde **nicht** (ghostty `main` braucht Zig 0.16, nixpkgs baut
v1.3.1 mit Zig 0.15.2). Geprueft wurde mit `zig 0.16.0 ast-check`:

```
zig ast-check src/Surface.zig        → sauber
```

Rot-Nachweis, damit die Pruefung nicht wertlos ist: `@as(f64, ...)` um das
`@floatFromInt` entfernt →

```
error: @floatFromInt must have a known result type
```

Die Pruefung kann also rot werden und deckt genau das geaenderte Konstrukt ab.
Was sie **nicht** abdeckt: Verhalten zur Laufzeit. Vor dem Einreichen sollte
das gebaut und von Hand gescrollt werden.

## Vouch — warum noch nichts eingereicht ist

Ghostty hat ein Vouch-System fuer Erstbeitragende (`.github/VOUCHED.td`,
359 Eintraege). **Meo98 steht nicht drauf.** PRs von ungevouchten Konten
werden automatisch geschlossen.

Reihenfolge:

1. Discussion in der Kategorie „Vouch Request" eroeffnen, Vorlage folgen,
   knapp halten.
2. `CONTRIBUTING.md` verlangt ausdruecklich: **in eigener Stimme schreiben,
   nicht von einer KI schreiben lassen.** Das ist keine Formalie — genau
   daran wird geprueft, ob jemand seinen Beitrag versteht.
3. Ein Maintainer kommentiert `!vouch`.
4. Erst danach der PR.

`AI_POLICY.md` verlangt zusaetzlich beim PR: **Offenlegung des Werkzeugs und
des Umfangs der KI-Beteiligung.** Die Commits tragen dafuer bereits ein
`Co-Authored-By`. Im PR-Text gehoert ein Satz dazu, was die KI getan hat
(Recherche, Patch gegen main rebasen, ast-check) und was nicht
(kein Laufzeit-Test).

Die Policy ist nicht KI-feindlich — sie richtet sich gegen ungepruefte
Einreichungen. Die Bedingung ist, den Code erklaeren zu koennen, ohne dabei
ein KI-Werkzeug zu brauchen. Dafuer ist dieses Dokument da.
