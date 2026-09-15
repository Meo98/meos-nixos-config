# nixup — Update-Architektur mit Ratsche und Blocker-Register

**Datum:** 2026-09-15
**Host(s):** meo, meo-work
**Status:** Entwurf zur Review
**Ersetzt teilweise:** `2026-08-20-automation-watcher-design.md` (Update-Checks
wandern nach `nixup status`; die lokalen Hygiene-Checks bleiben wo sie sind)

## 1. Problem

Die Update-Automation konvergiert seit vier Monaten nicht. Belege:

| Beobachtung | Beleg |
|---|---|
| Genau **ein** gemergter Update-PR seit Mai | `#6` (18.05.); `#7` ungemergt geschlossen; `#28` seit 24.08. offen |
| Update-PRs bekommen **nie** CI | `gh pr checks 28` → „no checks reported"; 3 Runs à `0s`, alle `action_required` |
| `build.yml` auf `main` läuft in den Timeout | 15.09.: zwei Runs `cancelled` nach 1h01m und 1h16m bei `timeout-minutes: 60` |
| Der Wächter meldet trotzdem „ok" | `report.txt` vom 14.09.: `GESAMT: ok` |

**Messung vom 15.09.** (Wegwerf-Kopie, `nix flake update`, `nix build --dry-run`):

```
ohne Pin   → 24 Derivations: ifcopenshell, freecad, ghostty + 21× Glue
mit Pin    → 22 Derivations: ghostty + 21× Glue
```

Das Update 31.08. → 13.09. war vollständig im Cache. Blockiert hat es **ein
einziges Blatt-Paket** (FreeCAD über `ifcopenshell` ./. `boost 1.91`).

### Die drei strukturellen Ursachen

**U1 — UND-Gatter ohne Ratsche.** `nix flake update` bewegt alle 16 Inputs
gemeinsam; ein roter Build rollt alle zurück. Die 15 gesunden Inputs werden
mit dem einen kranken verworfen, der nächste Versuch startet bei null und
läuft in dieselbe Wand. Das System *kann* nicht konvergieren.

**U2 — Workarounds ohne Verfallsdatum.** FreeCAD: pdal-Overlay (16.07.) →
Paket entfernt (16.07.) → Schein-Pin (August) → Abbruch (15.09.). Jeder
Schritt war für sich richtig. Keiner hatte eine Bedingung, unter der er
zurückgebaut wird, und niemand hat je nachgeschaut. Der ifcopenshell-Fix
(nixpkgs#563014) lag am 15.09. 08:15 UTC in master — unbemerkt.

**U3 — Monitoring misst das Falsche.** Aus dem August-Spec wurden
`update-loop`, `ci-build` und `open-prs` nie gebaut (0 Treffer in
`automation-health.nix`). `lock-age` misst absolutes Alter gegen 21 Tage
statt Abstand zum Kanal. Ergebnis: grünes Licht bei totem Prozess.

**Nebenkosten:** `ghostty-scroll-fix.nix` hängt einen Patch an → anderer
Derivation-Hash → kein Binary-Cache → ghostty kompiliert bei *jedem* Update
neu, mit `doCheck = 1` (Zig-Test-Suite). Das ist der Grund für den
CI-Timeout und für den Großteil der lokalen Wartezeit.

## 2. Ziele / Nicht-Ziele

**Ziele**
- Updates konvergieren: was grün ist, wird festgeschrieben, auch wenn anderes rot ist.
- Jeder Blocker ist benannt, datiert und hat eine **maschinell prüfbare Freigabe-Bedingung**.
- Bei Fehlschlag wird der Benutzer nach der Variante gefragt, nicht stillschweigend zurückgerollt.
- Erinnerungen nur bei Zustandsänderung, über Noctalia-Notification.
- Vorab-Auskunft in Sekunden statt nach 14 Minuten Kompilieren.

**Nicht-Ziele (bewusst)**
- Kein automatisches `switch` auf dem laufenden System. Aktivieren bleibt Knopfdruck.
- Kein automatisches Mergen. Kein Cloud-Build.
- Kein Anfassen der Hardware-Workarounds (i915-PSR, RTD3, dpcd-backlight,
  Docker liveRestore, CIFS soft-mount, zram+Swapfile, Ladelimit 80 %).
- `system.autoUpgrade` bleibt ungenutzt.
- Kein TUI-Dashboard in v1.

## 3. Architektur

Drei Teile, eine Wahrheit.

```
blockers.toml  ──┬──>  fallback-overlay.nix   (Nix liest, routet Pakete)
 (im Repo,       │
  versioniert)   └──>  nixup  (CLI: check / update / status / unpin)
                          │
                          └──>  systemd-user-Timer ──> notify-send (nur bei Änderung)
```

`blockers.toml` ist die einzige Quelle der Wahrheit für „was ist warum
festgenagelt". Nix liest sie, um Pakete umzurouten; `nixup` liest und
schreibt sie. Damit kann das Werkzeug Pins anlegen und auflösen, ohne dass
jemand Nix-Code von Hand editiert.

### 3.1 Isolations-Pin: ein Input statt N

Heute hat FreeCAD einen eigenen `nixpkgs-freecad`-Input, der auf denselben
beweglichen Branch zeigt wie `nixpkgs` — und damit **nichts isoliert**
(beide standen auf `34ab990`). Statt für jedes kranke Paket einen neuen
Input anzulegen:

```nix
# flake.nix — ein einziger Rückfall-Pin, auf einen REV, nicht auf einen Branch
nixpkgs-fallback.url = "github:nixos/nixpkgs/34ab99075ac4f7e40cf037eef32cb1c360bb85e9";
```

`fallback-overlay.nix` liest `blockers.toml` und routet jedes Paket mit
`strategy = "fallback"` auf diesen Pin:

```nix
# schematisch — routet ueber das package-Feld, nicht ueber den Register-Schluessel
{ lib, fallbackPkgs, ... }:
final: prev:
  let
    register = (builtins.fromTOML (builtins.readFile ../../blockers.toml)).blocker or { };
    pinned   = lib.filter (b: b.strategy == "fallback") (builtins.attrValues register);
  in builtins.listToAttrs (
    map (b: lib.nameValuePair b.package fallbackPkgs.${b.package}) pinned
  )
```

Die Nix-Schnipsel in diesem Dokument sind schematisch und zeigen die
Datenfluss-Absicht, nicht den fertigen Code.

`nixpkgs-freecad` entfällt; FreeCAD wird der erste Eintrag im Register.

### 3.2 Input-Gruppen

`nix flake update` bewegt alles. `nixup update` bewegt Gruppen einzeln:

| Gruppe | Inputs | Begründung |
|---|---|---|
| `core` | `nixpkgs`, `home-manager`, `stylix`, `nixvim`, `nix-index-database` | Versionen sind wechselseitig abhängig; HM-master gegen altes nixpkgs bricht |
| je Blatt | `nix-flatpak`, `antigravity-nix`, `awww`, `zen-browser`, `affinity-nix`, `sddm-noctalia` | unabhängig, einzeln testbar |
| `fallback` | `nixpkgs-fallback` | wird **nie** automatisch bewegt, nur per `nixup unpin` |
| Tag-gepinnt | `noctalia`, `dank-material-shell`, `piri`, `niri-pip` | bewegen sich bei `flake update` gar nicht → eigener Release-Wächter |

### 3.3 Die Befehle

**`nixup check`** — Sekunden, kompiliert nichts.
Wegwerf-Kopie → `nix flake update` → `nix build --dry-run` je Host → die
To-Build-Liste klassifizieren:
- *bekannt lokal* (ghostty, laut Allowlist) → Kostenhinweis
- *unerwartet* → wahrscheinlicher Blocker, mit Paketnamen

Ausgabe z. B.:
```
Update verfügbar: nixpkgs 31.08. → 13.09. (13 Tage Rückstand)
  Kosten : ghostty-1.3.1 (bekannt, baut lokal)
  Risiko : python3.14-ifcopenshell-0.8.0 baut unerwartet lokal
           └─ zieht freecad-1.1.3 → wahrscheinlicher Blocker
```

**`nixup update`** — die Ratsche. Je Gruppe: nur diese Gruppe aktualisieren,
`check`, bauen (beide Hosts), grün → committen und weiter; rot → nur diese
Gruppe zurücksetzen und den Benutzer fragen (siehe 3.5).

**`nixup status`** — Register + Freigabe-Prüfung + Aktionsliste.

**`nixup unpin <name>`** — Eintrag entfernen, Paket wieder aus `nixpkgs`
beziehen, bauen, bei Erfolg committen.

### 3.4 Die Freigabe-Prüfung

Die Bedingung wird **nicht** über GitHub-API-Ahnenforschung geprüft, sondern
direkt: *Baut oder lädt das Paket am aktuellen Kanal-Kopf?*

```
für jeden Blocker:
    evaluiere <kanal-kopf>.<paket>
    nix build --dry-run
    → "will be fetched"  ⇒ Fix ist da UND gecacht  ⇒ auflösbar
    → "will be built"    ⇒ Fix evtl. da, aber teuer ⇒ Hinweis
    → Eval-Fehler        ⇒ weiterhin blockiert
```

Das ist der definitive Test, braucht kein Token, und kann nicht lügen.
Das Feld `upstream = "NixOS/nixpkgs#563014"` bleibt als menschlicher
Kontext, ist aber nicht der Prüfmechanismus.

### 3.5 Verhalten bei Fehlschlag

Interaktiv fragt `nixup update` nach der Variante:

1. **Pin** — Paket auf `nixpkgs-fallback` routen, Blocker eintragen, Rest weiterlaufen lassen. *(Standard-Vorschlag)*
2. **Überspringen** — nur diese Gruppe zurück, nächster Lauf probiert erneut; als transient vermerkt.
3. **Patch** — Overlay-Gerüst anlegen und sagen, was hineingehört (halbautomatisch).
4. **Entfernen** — Paket auskommentieren, Blocker mit `strategy = "dropped"`.

Im Timer-Lauf (nicht-interaktiv) wird **nie** gefragt und **nie** gepinnt:
dort gilt immer „überspringen + vermerken". Pins sind eine menschliche
Entscheidung.

### 3.6 Register-Schema

```toml
[blocker.freecad]
package      = "freecad-wayland"
strategy     = "fallback"          # fallback | dropped | patched | transient
pinned_to    = "34ab99075ac4f7e40cf037eef32cb1c360bb85e9"
reason       = "ifcopenshell 0.8.0 ./. boost 1.91 (explicit optional ctor)"
upstream     = "NixOS/nixpkgs#563014"
since        = "2026-09-15"
last_checked = "2026-09-15"
```

### 3.7 Erinnerungen

systemd-User-Timer, täglich, `Persistent = true`, `RandomizedDelaySec`.
Führt `nixup check --quiet --notify` aus, vergleicht gegen
`~/.local/state/nixup/last.json` und benachrichtigt **nur bei Übergang**:

| Übergang | Meldung |
|---|---|
| sauberes Update verfügbar | „Update bereit, keine Blocker — `nixup update`" |
| neuer Blocker | „<Paket> blockiert das Update" |
| Blocker auflösbar | „<Paket>-Pin ist überflüssig — `nixup unpin <name>`" |
| Rückstand > 14 Tage | „Seit N Tagen kein Update" |

Kein tägliches Genörgel bei unverändertem Zustand.

## 4. Was zurückgebaut wird

Entsprechend der Entscheidung „lokal, CI nur als Linter":

- `flake-update.yml`, `automerge.yml` — entfernen. PR #28 schließen, Branch löschen.
- `build.yml` — entfernen. Die Ratsche baut lokal **beide** Hosts aus demselben
  Flake; ein CI-Build ohne beschreibbaren Cache kompiliert ghostty ohnehin
  jedes Mal neu und läuft in den Timeout.
- `lint.yml` — bleibt.
- `vulnix.yml`, `hyprland-tracker.yml`, `track-zaneyos.yml` — bleiben unberührt.
- `automation-health.nix` — `lock-age` entfernen (wird durch den echten
  Kanal-Abstand in `nixup status` ersetzt); die lokalen Hygiene-Checks
  (`git-sync`, `failed-units`, `nas-mounts`, `gc-timer`, `disk-space`) bleiben.
- `fu` — ersetzt durch `nixup update`. `fr` bleibt unverändert.

## 5. Sofortmaßnahmen (vor dem Werkzeug)

1. **FreeCAD-Pin echt machen:** `nixpkgs-freecad` → `nixpkgs-fallback` auf
   Rev `34ab990`. Entsperrt nachweislich das Update auf 13.09. (gemessen).
2. **ghostty-Bauzeit messen:** `doCheck = 1` ist bestätigt. Messen, welchen
   Anteil `checkPhase` an den ~15 Minuten hat; wenn dominant, im Overlay
   `doCheck = false` setzen. Der Patch betrifft `scrollCallback()` in
   `Surface.zig` — die volle Zig-Suite dafür ist unverhältnismäßig.

## 6. Testbarkeit

Reine Funktionen, ohne Nix-Aufruf testbar (pytest):
- Parsen der `--dry-run`-Ausgabe → Klassifikation bekannt/unerwartet
- Lock-Diff → Gruppenzuordnung
- Zustandsübergänge → welche Notification, welche nicht
- TOML-Register: lesen, Eintrag anlegen, auflösen

Mit Nix, aber ohne Bauen:
- `nixup check` gegen die Wegwerf-Kopie (heute schon manuell durchgespielt)

`--dry-run`-Modus für `update`, der alles tut außer committen.

## 7. Offene Punkte

- Sollen die Tag-gepinnten Inputs (noctalia, dms, piri, niri-pip) in v1 einen
  Release-Wächter bekommen oder erst in v2?
- Bleibt FreeCAD überhaupt in der Config? Es wurde am 16.07. schon einmal als
  „wird nicht mehr benoetigt" entfernt und hat seither drei Eingriffe gekostet.
  Der Pin macht die Frage unkritisch, beantwortet sie aber nicht.
