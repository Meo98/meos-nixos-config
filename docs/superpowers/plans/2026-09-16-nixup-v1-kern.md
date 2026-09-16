# nixup v1 (Kern) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein lokales CLI `nixup`, das Flake-Inputs gruppenweise aktualisiert, jede grüne Gruppe sofort festschreibt, jeden Blocker mit maschinell prüfbarer Freigabe-Bedingung registriert und nur bei Zustandsänderung erinnert.

**Architecture:** `blockers.toml` im Repo-Root ist die einzige Quelle der Wahrheit. Nix liest sie über ein Overlay und routet gepinnte Pakete auf den Rückfall-Pin `nixpkgs-fallback`; das Python-CLI liest und schreibt sie. Die Logik ist in reine, pytest-bare Module getrennt (Register, Dry-Run-Parser, Gruppen, Zustandsübergänge); alles, was `nix`/`git` aufruft, sitzt gekapselt in einem dünnen Wrapper.

**Tech Stack:** Python 3 (stdlib `tomllib` zum Lesen, `tomli-w` zum Schreiben, `argparse`, `subprocess`), pytest, Nix (home-manager-Modul, `writeShellApplication`-Muster analog `automation-health.nix`), systemd-User-Timer, `libnotify`.

**Spec:** `docs/superpowers/specs/2026-09-15-nixup-update-architecture-design.md`

**Abgrenzung:** Reparatur-Agent (Spec 3.8) und Release-Wächter (Spec 3.9) sind **nicht** Teil dieses Plans. Sie setzen auf dem hier festgelegten Register- und Auftragsformat auf und bekommen einen eigenen Plan.

## Global Constraints

- Sprache in Code-Kommentaren und Commit-Messages: Deutsch, ohne Umlaute in Commit-Messages (bestehende Repo-Konvention, siehe `git log`).
- Repo-Wurzel ist immer `~/nixos-config`. Beide Hosts sind `x86_64-linux`.
- Hosts: `meo`, `meo-work`. Jeder Build-Gate prüft **beide**.
- `nixup` aktiviert **nie** das System. Kein `nh os switch`, kein `nixos-rebuild switch`.
- Nie anfassen: Hardware-Workarounds (i915-PSR, RTD3, dpcd-backlight, Docker `liveRestore`, CIFS soft-mount, zram+Swapfile, Ladelimit 80 %), `smb-secrets`, `setup-secrets`, `keys/`.
- `nix build --dry-run` schreibt die Bauliste nach **stderr**, nicht stdout. Verifiziert am 2026-09-16 mit Nix 2.34.8.
- Einzel-Input-Update heisst `nix flake update <input>` (Nix ≥ 2.19). Nicht `nix flake lock --update-input`.
- `tomllib` kann nur lesen. Schreiben über `python3Packages.tomli-w` (1.2.0 in nixpkgs vorhanden).
- Tests laufen mit: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests -v`
- Der Rückfall-Pin heisst `nixpkgs-fallback` und zeigt auf einen **Rev**, nie auf einen Branch.
- Bestehender Zustand (bereits erledigt, nicht erneut tun): `nixpkgs-fallback` ist gesetzt, `blockers.toml` existiert mit dem Eintrag `freecad`, `hosts/meo/host-packages.nix` referenziert `inputs.nixpkgs-fallback`.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `modules/meo/nixup/src/nixup/register.py` | `blockers.toml` lesen, schreiben, Einträge anlegen/entfernen/filtern |
| `modules/meo/nixup/src/nixup/dryrun.py` | `nix build --dry-run`-stderr parsen, Bauliste in Glue/bekannt/unerwartet klassifizieren |
| `modules/meo/nixup/src/nixup/groups.py` | `flake.lock` lesen, Root-Inputs in Aktualisierungs-Gruppen einteilen |
| `modules/meo/nixup/src/nixup/state.py` | Zustands-Schnappschuss und Übergangslogik für Benachrichtigungen |
| `modules/meo/nixup/src/nixup/nixops.py` | Dünner `subprocess`-Wrapper um `nix` und `git`. Einzige Stelle mit Seiteneffekten |
| `modules/meo/nixup/src/nixup/cli.py` | `argparse`-Dispatch, Ausgabeformatierung, die vier Unterbefehle |
| `modules/meo/nixup/tests/` | pytest, eine Datei je reinem Modul |
| `modules/meo/nixup/default.nix` | Paketierung, systemd-User-Service und -Timer |
| `modules/meo/fallback-overlay.nix` | Liest `blockers.toml`, routet `strategy = "fallback"`-Pakete auf `nixpkgs-fallback` |

---

### Task 1: Register-Modul und Test-Grundgerüst

**Files:**
- Create: `modules/meo/nixup/src/nixup/__init__.py`
- Create: `modules/meo/nixup/src/nixup/register.py`
- Test: `modules/meo/nixup/tests/test_register.py`

**Interfaces:**
- Consumes: nichts.
- Produces: `Blocker` (dataclass mit Feldern `name, package, strategy, reason, upstream, rev, since, last_checked`), `load(path) -> dict[str, Blocker]`, `save(path, dict[str, Blocker]) -> None`, `add(reg, blocker) -> dict`, `remove(reg, name) -> dict`, `pinned_packages(reg) -> list[str]`, Konstante `STRATEGIES`.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_register.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.register import Blocker, load, save, add, remove, pinned_packages

def test_load_liest_bestehenden_eintrag(tmp_path):
    p = tmp_path / "blockers.toml"
    p.write_text('''
[blocker.freecad]
package = "freecad-wayland"
strategy = "fallback"
rev = "34ab990"
reason = "ifcopenshell ./. boost 1.91"
since = "2026-09-15"
''')
    reg = load(p)
    assert set(reg) == {"freecad"}
    assert reg["freecad"].package == "freecad-wayland"
    assert reg["freecad"].strategy == "fallback"

def test_load_bei_fehlender_datei_ist_leer(tmp_path):
    assert load(tmp_path / "gibtsnicht.toml") == {}

def test_roundtrip_erhaelt_alle_felder(tmp_path):
    p = tmp_path / "blockers.toml"
    b = Blocker(name="freecad", package="freecad-wayland", strategy="fallback",
                reason="boom", upstream="NixOS/nixpkgs#563014", rev="34ab990",
                since="2026-09-15", last_checked="2026-09-16")
    save(p, {"freecad": b})
    assert load(p)["freecad"] == b

def test_add_ist_pur(tmp_path):
    reg = {}
    b = Blocker(name="x", package="x", strategy="transient")
    neu = add(reg, b)
    assert reg == {}          # Original unveraendert
    assert set(neu) == {"x"}

def test_remove_ist_pur():
    b = Blocker(name="x", package="x", strategy="transient")
    reg = {"x": b}
    assert remove(reg, "x") == {}
    assert set(reg) == {"x"}

def test_remove_unbekannt_wirft():
    import pytest
    with pytest.raises(KeyError):
        remove({}, "nope")

def test_pinned_packages_nur_fallback():
    reg = {
        "a": Blocker(name="a", package="pkg-a", strategy="fallback"),
        "b": Blocker(name="b", package="pkg-b", strategy="transient"),
        "c": Blocker(name="c", package="pkg-c", strategy="fallback"),
    }
    assert sorted(pinned_packages(reg)) == ["pkg-a", "pkg-c"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_register.py -v`
Expected: FAIL mit `ModuleNotFoundError: No module named 'nixup'`

- [ ] **Step 3: Write minimal implementation**

```python
# modules/meo/nixup/src/nixup/__init__.py
```
(leere Datei)

```python
# modules/meo/nixup/src/nixup/register.py
"""Lesen und Schreiben von blockers.toml.

Das Register ist die einzige Quelle der Wahrheit dafuer, welches Paket warum
festgenagelt ist. Nix liest dieselbe Datei ueber fallback-overlay.nix.
Alle Funktionen hier sind pur: sie geben neue Dicts zurueck statt zu mutieren,
damit der Aufrufer entscheidet, wann geschrieben wird.
"""
from __future__ import annotations

import tomllib
from dataclasses import asdict, dataclass, field
from pathlib import Path

import tomli_w

STRATEGIES = ("fallback", "dropped", "patched", "transient")


@dataclass(frozen=True)
class Blocker:
    name: str
    package: str
    strategy: str
    reason: str = ""
    upstream: str = ""
    rev: str = ""
    since: str = ""
    last_checked: str = ""


def load(path: Path) -> dict[str, Blocker]:
    if not Path(path).exists():
        return {}
    raw = tomllib.loads(Path(path).read_text())
    out: dict[str, Blocker] = {}
    for name, body in (raw.get("blocker") or {}).items():
        fields = {k: v for k, v in body.items() if k in Blocker.__annotations__}
        out[name] = Blocker(name=name, **fields)
    return out


def save(path: Path, register: dict[str, Blocker]) -> None:
    doc = {"blocker": {}}
    for name, b in sorted(register.items()):
        body = {k: v for k, v in asdict(b).items() if k != "name" and v != ""}
        doc["blocker"][name] = body
    Path(path).write_text(tomli_w.dumps(doc))


def add(register: dict[str, Blocker], blocker: Blocker) -> dict[str, Blocker]:
    return {**register, blocker.name: blocker}


def remove(register: dict[str, Blocker], name: str) -> dict[str, Blocker]:
    if name not in register:
        raise KeyError(name)
    return {k: v for k, v in register.items() if k != name}


def pinned_packages(register: dict[str, Blocker]) -> list[str]:
    return [b.package for b in register.values() if b.strategy == "fallback"]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_register.py -v`
Expected: PASS, 7 Tests

- [ ] **Step 5: Gegenprobe mit dem echten Register**

Run: `nix shell nixpkgs#python3Packages.tomli-w -c python3 -c "
import sys; sys.path.insert(0, 'modules/meo/nixup/src')
from nixup.register import load, pinned_packages
reg = load('blockers.toml')
print('Eintraege:', list(reg))
print('gepinnt  :', pinned_packages(reg))
"`
Expected: `Eintraege: ['freecad']` und `gepinnt: ['freecad-wayland']`

- [ ] **Step 6: Commit**

```bash
git add modules/meo/nixup/src/nixup/__init__.py modules/meo/nixup/src/nixup/register.py modules/meo/nixup/tests/test_register.py
git commit -m "nixup: Register-Modul fuer blockers.toml

Reine Lese-/Schreiblogik, keine Seiteneffekte. tomllib kann nur lesen,
deshalb tomli-w zum Schreiben. add/remove geben neue Dicts zurueck, damit
der Aufrufer entscheidet wann geschrieben wird."
```

---

### Task 2: Dry-Run-Parser

**Files:**
- Create: `modules/meo/nixup/src/nixup/dryrun.py`
- Test: `modules/meo/nixup/tests/test_dryrun.py`

**Interfaces:**
- Consumes: nichts.
- Produces: `DryRun` (dataclass, Felder `to_build: list[str]`, `to_fetch: list[str]`), `parse(stderr: str) -> DryRun`, `is_glue(name: str) -> bool`, `classify(d: DryRun, known_local: set[str]) -> tuple[list[str], list[str]]` mit Rückgabe `(erwartet, unerwartet)`, Konstante `GLUE_PREFIXES`.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_dryrun.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.dryrun import DryRun, parse, is_glue, classify

# Echte Ausgabe vom 2026-09-15, gekuerzt. --dry-run schreibt nach stderr.
ECHT = """these 24 derivations will be built:
  /nix/store/znnsyn3m4xlm84zxj6z13i4xavfdgwl7-python3.14-ifcopenshell-0.8.0.drv
  /nix/store/1dvrm12l4pxndhd0y5a99bwm1kvz40p7-freecad-1.1.3.drv
  /nix/store/9lvi8869zx8iixcj9rb94n62c0np0r46-ghostty-1.3.1.drv
  /nix/store/0v0s4wrdqkq5b62my7b871pbzrj3lhwz-system-path.drv
  /nix/store/80a666mfjybd3iznwlggm2cmid472inb-X-Restart-Triggers-polkit.drv
  /nix/store/91xrqcz7nkqwqbmylwi4sd7hygzxd8pa-unit-polkit.service.drv
these 31 paths will be fetched (40.6 MiB download, 150.1 MiB unpacked):
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-hello-2.12
"""

def test_parse_trennt_bauen_und_holen():
    d = parse(ECHT)
    assert "python3.14-ifcopenshell-0.8.0" in d.to_build
    assert "freecad-1.1.3" in d.to_build
    assert d.to_fetch == ["hello-2.12"]

def test_parse_entfernt_hash_und_drv_suffix():
    d = parse(ECHT)
    assert all(not n.endswith(".drv") for n in d.to_build)
    assert all("/nix/store" not in n for n in d.to_build)

def test_parse_leere_ausgabe():
    assert parse("") == DryRun(to_build=[], to_fetch=[])

def test_parse_singular_form():
    s = "this derivation will be built:\n  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo-1.0.drv\n"
    assert parse(s).to_build == ["foo-1.0"]

def test_is_glue_erkennt_konfigurations_kleinkram():
    assert is_glue("unit-polkit.service")
    assert is_glue("X-Restart-Triggers-polkit")
    assert is_glue("system-path")
    assert is_glue("etc")
    assert is_glue("nixos-system-meo-26.11.20260913.ef34387")
    assert not is_glue("freecad-1.1.3")
    assert not is_glue("ghostty-1.3.1")

def test_classify_trennt_bekannt_von_unerwartet():
    d = parse(ECHT)
    erwartet, unerwartet = classify(d, known_local={"ghostty"})
    assert "ghostty-1.3.1" in erwartet
    assert "python3.14-ifcopenshell-0.8.0" in unerwartet
    assert "freecad-1.1.3" in unerwartet
    # Glue taucht in keiner der beiden Listen auf
    assert not any("unit-polkit" in n for n in erwartet + unerwartet)

def test_classify_ohne_unerwartetes_ist_sauber():
    s = ("these 2 derivations will be built:\n"
         "  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-ghostty-1.3.1.drv\n"
         "  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-system-path.drv\n")
    erwartet, unerwartet = classify(parse(s), known_local={"ghostty"})
    assert erwartet == ["ghostty-1.3.1"]
    assert unerwartet == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_dryrun.py -v`
Expected: FAIL mit `ModuleNotFoundError: No module named 'nixup.dryrun'`

- [ ] **Step 3: Write minimal implementation**

```python
# modules/meo/nixup/src/nixup/dryrun.py
"""Parsen und Klassifizieren der Ausgabe von `nix build --dry-run`.

Wichtig: die Bauliste geht nach STDERR, nicht stdout (verifiziert 2026-09-16,
Nix 2.34.8). `--json` hilft nicht, es enthaelt nur die finale Derivation.

Der Zweck: in Sekunden beantworten, was ein Update kosten und was es brechen
wuerde -- statt es nach 14 Minuten Kompilieren herauszufinden.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

# Konfigurations-Kleinkram, der bei jeder Aenderung neu erzeugt wird und
# nichts ueber Risiko oder Kosten aussagt.
GLUE_PREFIXES = (
    "unit-",
    "user-units",
    "system-units",
    "X-Restart-Triggers-",
    "system-path",
    "home-manager-",
    "hm-",
    "hm_",
    "nixos-system-",
    "activation-script",
    "activate",
    "user-environment",
    "user-dbus-services",
    "dbus-1",
    "etc-",
    "options.json",
    "dry-activate",
)
GLUE_EXACT = {"etc", "firmware", "desktops", "graphics-drivers", "boot.json"}

_STORE = re.compile(r"^\s+(/nix/store/[a-z0-9]{32}-(?P<name>.+?))(?:\.drv)?\s*$")
_BUILD_HDR = re.compile(r"^(these \d+ derivations|this derivation) will be built:")
_FETCH_HDR = re.compile(r"^(these \d+ paths|this path) will be fetched")


@dataclass
class DryRun:
    to_build: list[str] = field(default_factory=list)
    to_fetch: list[str] = field(default_factory=list)


def parse(stderr: str) -> DryRun:
    out = DryRun()
    target: list[str] | None = None
    for line in stderr.splitlines():
        if _BUILD_HDR.match(line):
            target = out.to_build
            continue
        if _FETCH_HDR.match(line):
            target = out.to_fetch
            continue
        m = _STORE.match(line)
        if m and target is not None:
            target.append(m.group("name"))
            continue
        if line and not line.startswith(" "):
            target = None
    return out


def is_glue(name: str) -> bool:
    if name in GLUE_EXACT:
        return True
    return name.startswith(GLUE_PREFIXES)


def _base(name: str) -> str:
    """'ghostty-1.3.1' -> 'ghostty'. Versions-Suffix abtrennen."""
    return re.sub(r"-\d[\w.+]*$", "", name)


def classify(d: DryRun, known_local: set[str]) -> tuple[list[str], list[str]]:
    """Trennt echte Pakete in (erwartet, unerwartet). Glue faellt raus."""
    erwartet, unerwartet = [], []
    for name in d.to_build:
        if is_glue(name):
            continue
        (erwartet if _base(name) in known_local else unerwartet).append(name)
    return erwartet, unerwartet
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_dryrun.py -v`
Expected: PASS, 7 Tests

- [ ] **Step 5: Gegenprobe gegen echte Nix-Ausgabe**

Run: `nix build ".#nixosConfigurations.meo-work.config.system.build.toplevel" --dry-run 2>&1 >/dev/null | nix shell nixpkgs#python3 -c python3 -c "
import sys; sys.path.insert(0, 'modules/meo/nixup/src')
from nixup.dryrun import parse, classify
d = parse(sys.stdin.read())
e, u = classify(d, {'ghostty'})
print('gesamt zu bauen:', len(d.to_build))
print('erwartet       :', e)
print('unerwartet     :', u)
"`
Expected: `gesamt zu bauen` dreistellig, `erwartet` enthält `ghostty-1.3.1`, `unerwartet` enthält `ferdium-*` und `glibc-locales-*` — aber **kein** `unit-*` oder `etc-*`.

- [ ] **Step 6: Commit**

```bash
git add modules/meo/nixup/src/nixup/dryrun.py modules/meo/nixup/tests/test_dryrun.py
git commit -m "nixup: Dry-Run-Parser mit Glue-Filter

Beantwortet in Sekunden, was ein Update kostet und was es bricht. Die
Bauliste von nix build --dry-run geht nach stderr, nicht stdout. Der
Glue-Filter wirft Konfigurations-Kleinkram (unit-*, etc-*, X-Restart-*)
raus, der bei jeder Aenderung neu erzeugt wird und nichts aussagt --
am 15.09. waren 22 von 24 Derivations genau das."
```

---

### Task 3: Input-Gruppen aus flake.lock

**Files:**
- Create: `modules/meo/nixup/src/nixup/groups.py`
- Test: `modules/meo/nixup/tests/test_groups.py`

**Interfaces:**
- Consumes: nichts.
- Produces: `Group` (dataclass, Felder `name: str`, `inputs: list[str]`), `root_inputs(lock: dict) -> list[str]`, `plan_groups(lock: dict) -> list[Group]`, `locked_timestamp(lock: dict, input_name: str) -> int | None`, Konstanten `CORE`, `NEVER_AUTO`, `TAG_PINNED`.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_groups.py
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.groups import Group, root_inputs, plan_groups, locked_timestamp, CORE, NEVER_AUTO, TAG_PINNED

LOCK = {
    "root": "root",
    "nodes": {
        "root": {"inputs": {
            "nixpkgs": "nixpkgs_3",
            "nixpkgs-fallback": "nixpkgs-fallback",
            "home-manager": "home-manager",
            "stylix": "stylix",
            "nixvim": "nixvim",
            "nix-index-database": "nix-index-database",
            "zen-browser": "zen-browser",
            "awww": "awww",
            "noctalia": "noctalia",
            "piri": "piri",
        }},
        "nixpkgs_3": {"locked": {"lastModified": 1788179007, "rev": "34ab990"}},
        "nixpkgs-fallback": {"locked": {"lastModified": 1788179007, "rev": "34ab990"}},
        "home-manager": {"locked": {"lastModified": 1788179007}},
        "stylix": {"locked": {"lastModified": 1788179007}},
        "nixvim": {"locked": {"lastModified": 1788179007}},
        "nix-index-database": {"locked": {"lastModified": 1788179007}},
        "zen-browser": {"locked": {"lastModified": 1788179007}},
        "awww": {"locked": {"lastModified": 1788179007}},
        "noctalia": {"locked": {"lastModified": 1788179007}},
        "piri": {"locked": {"lastModified": 1788179007}},
    },
}

def test_root_inputs_sind_sortiert_und_vollstaendig():
    assert root_inputs(LOCK) == sorted(LOCK["nodes"]["root"]["inputs"])

def test_core_ist_eine_einzige_gruppe():
    gruppen = {g.name: g for g in plan_groups(LOCK)}
    assert "core" in gruppen
    assert set(gruppen["core"].inputs) == {
        "nixpkgs", "home-manager", "stylix", "nixvim", "nix-index-database"}

def test_blaetter_bekommen_je_eine_eigene_gruppe():
    gruppen = {g.name: g for g in plan_groups(LOCK)}
    assert gruppen["zen-browser"].inputs == ["zen-browser"]
    assert gruppen["awww"].inputs == ["awww"]

def test_fallback_wird_nie_automatisch_bewegt():
    assert "nixpkgs-fallback" in NEVER_AUTO
    alle = [i for g in plan_groups(LOCK) for i in g.inputs]
    assert "nixpkgs-fallback" not in alle

def test_tag_gepinnte_kommen_nicht_in_den_ratschen_lauf():
    alle = [i for g in plan_groups(LOCK) for i in g.inputs]
    assert "noctalia" not in alle
    assert "piri" not in alle

def test_core_gruppe_kommt_zuerst():
    assert plan_groups(LOCK)[0].name == "core"

def test_locked_timestamp_folgt_der_node_referenz():
    # root sagt nixpkgs -> nixpkgs_3; der Zeitstempel steckt im Zielknoten
    assert locked_timestamp(LOCK, "nixpkgs") == 1788179007

def test_locked_timestamp_unbekannt_ist_none():
    assert locked_timestamp(LOCK, "gibtsnicht") is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_groups.py -v`
Expected: FAIL mit `ModuleNotFoundError: No module named 'nixup.groups'`

- [ ] **Step 3: Write minimal implementation**

```python
# modules/meo/nixup/src/nixup/groups.py
"""Einteilung der Flake-Inputs in Aktualisierungs-Gruppen.

Der Kern der Ratsche: statt alle Inputs gemeinsam zu bewegen (ein rotes
Paket rollt alles zurueck, nichts konvergiert), wird je Gruppe einzeln
aktualisiert und gebaut. Was gruen ist, wird sofort festgeschrieben.

`core` bleibt eine Gruppe, weil home-manager/stylix/nixvim gegen ein altes
nixpkgs brechen -- ihre Versionen sind wechselseitig abhaengig.
"""
from __future__ import annotations

from dataclasses import dataclass

# Wechselseitig abhaengig, muessen gemeinsam wandern.
CORE = ("nixpkgs", "home-manager", "stylix", "nixvim", "nix-index-database")

# Der Rueckfall-Pin. Wird ausschliesslich per `nixup unpin` bewegt.
NEVER_AUTO = ("nixpkgs-fallback",)

# Auf Release-Tags gepinnt: bewegen sich bei `nix flake update` gar nicht.
# Sie brauchen den Release-Waechter (Spec 3.9), nicht die Ratsche.
TAG_PINNED = ("noctalia", "dank-material-shell", "piri", "niri-pip")


@dataclass
class Group:
    name: str
    inputs: list[str]


def root_inputs(lock: dict) -> list[str]:
    root = lock["nodes"][lock["root"]]
    return sorted(root.get("inputs", {}))


def plan_groups(lock: dict) -> list[Group]:
    """core zuerst, danach jedes Blatt einzeln (alphabetisch)."""
    vorhanden = set(root_inputs(lock))
    core = [i for i in CORE if i in vorhanden]
    ausgenommen = set(CORE) | set(NEVER_AUTO) | set(TAG_PINNED)
    blaetter = sorted(i for i in vorhanden if i not in ausgenommen)

    gruppen: list[Group] = []
    if core:
        gruppen.append(Group(name="core", inputs=core))
    gruppen.extend(Group(name=i, inputs=[i]) for i in blaetter)
    return gruppen


def locked_timestamp(lock: dict, input_name: str) -> int | None:
    """lastModified des Knotens, auf den der Root-Input zeigt.

    Der Root-Input-Name und der Knotenname sind nicht dasselbe: `nixpkgs`
    zeigt in dieser Config auf den Knoten `nixpkgs_3`.
    """
    root = lock["nodes"][lock["root"]]
    ref = root.get("inputs", {}).get(input_name)
    if not isinstance(ref, str):
        return None
    node = lock["nodes"].get(ref, {})
    return node.get("locked", {}).get("lastModified")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_groups.py -v`
Expected: PASS, 8 Tests

- [ ] **Step 5: Gegenprobe gegen die echte flake.lock**

Run: `python3 -c "
import sys, json; sys.path.insert(0, 'modules/meo/nixup/src')
from nixup.groups import plan_groups, locked_timestamp
lock = json.load(open('flake.lock'))
for g in plan_groups(lock): print(f'{g.name:22} {g.inputs}')
print('nixpkgs lastModified:', locked_timestamp(lock, 'nixpkgs'))
"`
Expected: `core` mit fünf Inputs zuerst, danach je eine Gruppe für `affinity-nix`, `antigravity-nix`, `awww`, `nix-flatpak`, `sddm-noctalia`, `zen-browser`. Kein `nixpkgs-fallback`, kein `noctalia`/`piri`/`niri-pip`/`dank-material-shell`.

- [ ] **Step 6: Commit**

```bash
git add modules/meo/nixup/src/nixup/groups.py modules/meo/nixup/tests/test_groups.py
git commit -m "nixup: Input-Gruppen aus flake.lock

Der Kern der Ratsche. core (nixpkgs + home-manager + stylix + nixvim +
nix-index-database) bleibt eine Gruppe, weil die Versionen wechselseitig
abhaengig sind; jedes Blatt bekommt eine eigene. nixpkgs-fallback und die
tag-gepinnten Inputs sind ausgenommen.

locked_timestamp folgt bewusst der Node-Referenz: der Root-Input nixpkgs
zeigt in dieser Config auf den Knoten nixpkgs_3, ein direkter Namens-Lookup
laege falsch."
```

---

### Task 4: Zustandsübergänge für Benachrichtigungen

**Files:**
- Create: `modules/meo/nixup/src/nixup/state.py`
- Test: `modules/meo/nixup/tests/test_state.py`

**Interfaces:**
- Consumes: nichts.
- Produces: `Snapshot` (dataclass, Felder `update_available: bool`, `unexpected: list[str]`, `blockers: list[str]`, `releasable: list[str]`, `days_behind: int`), `Notification` (dataclass, Felder `kind: str`, `text: str`), `transitions(prev: Snapshot | None, cur: Snapshot) -> list[Notification]`, `load_state(path) -> Snapshot | None`, `save_state(path, snap) -> None`, Konstante `STALE_DAYS = 14`.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_state.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.state import Snapshot, transitions, load_state, save_state, STALE_DAYS

def snap(**kw):
    basis = dict(update_available=False, unexpected=[], blockers=[], releasable=[], days_behind=0)
    basis.update(kw)
    return Snapshot(**basis)

def kinds(ns):
    return sorted(n.kind for n in ns)

def test_unveraenderter_zustand_meldet_nichts():
    s = snap(update_available=True, blockers=["freecad"])
    assert transitions(s, s) == []

def test_sauberes_update_wird_gemeldet():
    vorher = snap(update_available=False)
    jetzt = snap(update_available=True)
    assert "clean-update" in kinds(transitions(vorher, jetzt))

def test_update_mit_unerwartetem_ist_nicht_sauber():
    jetzt = snap(update_available=True, unexpected=["ifcopenshell-0.8.0"])
    assert "clean-update" not in kinds(transitions(snap(), jetzt))

def test_neuer_blocker_wird_gemeldet_mit_namen():
    ns = transitions(snap(blockers=["a"]), snap(blockers=["a", "b"]))
    assert [n for n in ns if n.kind == "new-blocker"]
    assert "b" in [n for n in ns if n.kind == "new-blocker"][0].text

def test_bekannter_blocker_wird_nicht_erneut_gemeldet():
    s = snap(blockers=["a"])
    assert "new-blocker" not in kinds(transitions(s, s))

def test_aufloesbarer_blocker_wird_gemeldet():
    ns = transitions(snap(blockers=["freecad"]), snap(blockers=["freecad"], releasable=["freecad"]))
    treffer = [n for n in ns if n.kind == "releasable"]
    assert treffer and "nixup unpin freecad" in treffer[0].text

def test_rueckstand_meldet_beim_ueberschreiten_genau_einmal():
    vorher = snap(days_behind=STALE_DAYS)
    jetzt = snap(days_behind=STALE_DAYS + 1)
    assert "stale" in kinds(transitions(vorher, jetzt))
    # nochmal derselbe Zustand -> kein erneutes Genoergel
    assert "stale" not in kinds(transitions(jetzt, jetzt))

def test_erster_lauf_ohne_vorzustand_meldet_die_lage():
    ns = transitions(None, snap(update_available=True, blockers=["freecad"]))
    assert "clean-update" in kinds(ns)
    assert "new-blocker" in kinds(ns)

def test_state_roundtrip(tmp_path):
    p = tmp_path / "last.json"
    s = snap(update_available=True, blockers=["x"], days_behind=3)
    save_state(p, s)
    assert load_state(p) == s

def test_load_state_ohne_datei_ist_none(tmp_path):
    assert load_state(tmp_path / "nichts.json") is None

def test_load_state_bei_kaputtem_json_ist_none(tmp_path):
    p = tmp_path / "last.json"
    p.write_text("{kaputt")
    assert load_state(p) is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_state.py -v`
Expected: FAIL mit `ModuleNotFoundError: No module named 'nixup.state'`

- [ ] **Step 3: Write minimal implementation**

```python
# modules/meo/nixup/src/nixup/state.py
"""Zustands-Schnappschuss und Uebergangslogik.

Benachrichtigt wird ausschliesslich bei einer AENDERUNG. Ein Timer, der
taeglich dasselbe meldet, wird weggeklickt und ist danach wertlos -- das ist
derselbe Fehler wie beim alten Waechter, nur andersherum.
"""
from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path

STALE_DAYS = 14


@dataclass
class Snapshot:
    update_available: bool = False
    unexpected: list[str] = field(default_factory=list)
    blockers: list[str] = field(default_factory=list)
    releasable: list[str] = field(default_factory=list)
    days_behind: int = 0


@dataclass
class Notification:
    kind: str
    text: str


def transitions(prev: Snapshot | None, cur: Snapshot) -> list[Notification]:
    leer = Snapshot()
    basis = prev if prev is not None else leer
    erster_lauf = prev is None
    out: list[Notification] = []

    sauber_jetzt = cur.update_available and not cur.unexpected
    sauber_vorher = basis.update_available and not basis.unexpected
    if sauber_jetzt and (erster_lauf or not sauber_vorher):
        out.append(Notification("clean-update",
                                "Update bereit, keine Blocker — `nixup update`"))

    neu = [b for b in cur.blockers if b not in basis.blockers]
    for b in neu:
        out.append(Notification("new-blocker", f"{b} blockiert das Update"))

    frisch_loesbar = [r for r in cur.releasable if r not in basis.releasable]
    for r in frisch_loesbar:
        out.append(Notification("releasable",
                                f"{r}-Pin ist ueberfluessig — `nixup unpin {r}`"))

    if cur.days_behind > STALE_DAYS and (erster_lauf or basis.days_behind <= STALE_DAYS):
        out.append(Notification("stale", f"Seit {cur.days_behind} Tagen kein Update"))

    return out


def load_state(path: Path) -> Snapshot | None:
    p = Path(path)
    if not p.exists():
        return None
    try:
        return Snapshot(**json.loads(p.read_text()))
    except (json.JSONDecodeError, TypeError):
        return None


def save_state(path: Path, snap: Snapshot) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(asdict(snap), indent=2))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_state.py -v`
Expected: PASS, 11 Tests

- [ ] **Step 5: Commit**

```bash
git add modules/meo/nixup/src/nixup/state.py modules/meo/nixup/tests/test_state.py
git commit -m "nixup: Zustandsuebergaenge fuer Benachrichtigungen

Gemeldet wird nur bei Aenderung. Ein Timer der taeglich dasselbe sagt wird
weggeklickt und ist danach wertlos -- derselbe Fehler wie beim alten
Waechter, nur andersherum. Kaputtes state-JSON wird als 'kein Vorzustand'
behandelt statt zu werfen, damit ein beschaedigter Cache den Timer nicht
dauerhaft lahmlegt."
```

---

### Task 5: Nix-/Git-Wrapper

**Files:**
- Create: `modules/meo/nixup/src/nixup/nixops.py`
- Test: `modules/meo/nixup/tests/test_nixops.py`

**Interfaces:**
- Consumes: nichts.
- Produces: `Run` (dataclass, Felder `code: int`, `out: str`, `err: str`), `run(cmd: list[str], cwd=None) -> Run`, und die reinen Kommando-Bauer `cmd_dry_run(host) -> list[str]`, `cmd_build(host) -> list[str]`, `cmd_flake_update(inputs: list[str] | None) -> list[str]`, `cmd_release_probe(package: str) -> list[str]`, sowie `scratch_copy(repo: Path, dest: Path) -> Path`.

**Begründung der Trennung:** Was `subprocess` aufruft, ist schwer zu testen; wie das Kommando aussieht, ist trivial zu testen und genau da sitzen die Fehler (falsche Flags, falscher Stream, veraltete Syntax). Deshalb sind die Kommando-Bauer pur und einzeln geprüft.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_nixops.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.nixops import (Run, run, cmd_dry_run, cmd_build,
                          cmd_flake_update, cmd_release_probe, scratch_copy)

def test_dry_run_kommando_zielt_auf_den_host_toplevel():
    c = cmd_dry_run("meo")
    assert c[:2] == ["nix", "build"]
    assert ".#nixosConfigurations.meo.config.system.build.toplevel" in c
    assert "--dry-run" in c

def test_build_kommando_hat_kein_dry_run():
    assert "--dry-run" not in cmd_build("meo-work")

def test_flake_update_ohne_inputs_aktualisiert_alles():
    assert cmd_flake_update(None) == ["nix", "flake", "update"]

def test_flake_update_mit_inputs_nennt_sie_einzeln():
    # Nix >= 2.19: `nix flake update <input>`, NICHT `--update-input`
    c = cmd_flake_update(["nixpkgs", "home-manager"])
    assert c == ["nix", "flake", "update", "nixpkgs", "home-manager"]
    assert "--update-input" not in c

def test_release_probe_zielt_auf_den_kanal_kopf():
    c = cmd_release_probe("freecad-wayland")
    assert "github:nixos/nixpkgs/nixos-unstable#freecad-wayland" in c
    assert "--dry-run" in c

def test_run_liefert_code_und_beide_streams():
    r = run(["sh", "-c", "echo raus; echo rein >&2; exit 3"])
    assert r.code == 3
    assert "raus" in r.out
    assert "rein" in r.err

def test_scratch_copy_kopiert_ohne_git(tmp_path):
    repo = tmp_path / "repo"
    (repo / ".git").mkdir(parents=True)
    (repo / ".git" / "HEAD").write_text("ref: refs/heads/main")
    (repo / "flake.nix").write_text("{}")
    ziel = scratch_copy(repo, tmp_path / "kopie")
    assert (ziel / "flake.nix").exists()
    assert not (ziel / ".git").exists()

def test_scratch_copy_ueberschreibt_altes_ziel(tmp_path):
    repo = tmp_path / "repo"; repo.mkdir()
    (repo / "flake.nix").write_text("neu")
    ziel = tmp_path / "kopie"; ziel.mkdir()
    (ziel / "altmuell.txt").write_text("weg damit")
    scratch_copy(repo, ziel)
    assert not (ziel / "altmuell.txt").exists()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_nixops.py -v`
Expected: FAIL mit `ModuleNotFoundError: No module named 'nixup.nixops'`

- [ ] **Step 3: Write minimal implementation**

```python
# modules/meo/nixup/src/nixup/nixops.py
"""Duenner Wrapper um `nix` und `git`. Einzige Stelle mit Seiteneffekten.

Die Kommando-Bauer sind bewusst pur und einzeln getestet: was subprocess
tut, ist schwer zu pruefen -- wie das Kommando aussieht, ist trivial zu
pruefen, und genau dort sitzen die Fehler (falsche Flags, veraltete Syntax).
"""
from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

TOPLEVEL = ".#nixosConfigurations.{host}.config.system.build.toplevel"
CHANNEL = "github:nixos/nixpkgs/nixos-unstable"


@dataclass
class Run:
    code: int
    out: str
    err: str


def run(cmd: list[str], cwd: Path | None = None) -> Run:
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return Run(code=p.returncode, out=p.stdout, err=p.stderr)


def cmd_dry_run(host: str) -> list[str]:
    return ["nix", "build", TOPLEVEL.format(host=host), "--dry-run"]


def cmd_build(host: str) -> list[str]:
    return ["nix", "build", TOPLEVEL.format(host=host), "--no-link"]


def cmd_flake_update(inputs: list[str] | None) -> list[str]:
    # Nix >= 2.19. `nix flake lock --update-input` ist veraltet.
    basis = ["nix", "flake", "update"]
    return basis if not inputs else basis + list(inputs)


def cmd_release_probe(package: str) -> list[str]:
    """Baut das Paket am Kanal-Kopf trocken.

    Das ist die Freigabe-Pruefung aus Spec 3.4: 'will be fetched' heisst,
    der Fix ist da UND gecacht. Kein Token, keine Ahnenforschung ueber
    Commit-Vorfahren, und es kann nicht luegen.
    """
    return ["nix", "build", f"{CHANNEL}#{package}", "--dry-run", "--no-link"]


def scratch_copy(repo: Path, dest: Path) -> Path:
    """Wegwerf-Kopie ohne .git, damit Probelaeufe das Repo nicht anfassen."""
    dest = Path(dest)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(repo, dest, ignore=shutil.ignore_patterns(".git", "result", "result-*"))
    return dest
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_nixops.py -v`
Expected: PASS, 8 Tests

- [ ] **Step 5: Commit**

```bash
git add modules/meo/nixup/src/nixup/nixops.py modules/meo/nixup/tests/test_nixops.py
git commit -m "nixup: Nix-/Git-Wrapper mit puren Kommando-Bauern

Seiteneffekte an einer Stelle gebuendelt. Die Kommando-Bauer sind pur und
einzeln geprueft, weil dort die Fehler sitzen: cmd_flake_update nutzt die
Nix->=2.19-Syntax 'nix flake update <input>' statt des veralteten
--update-input, und cmd_release_probe implementiert die Freigabe-Pruefung
ohne GitHub-Token."
```

---

### Task 6: `nixup check`

**Files:**
- Create: `modules/meo/nixup/src/nixup/cli.py`
- Test: `modules/meo/nixup/tests/test_cli_check.py`

**Interfaces:**
- Consumes: `dryrun.parse/classify`, `groups.plan_groups/locked_timestamp`, `nixops.*`, `register.load`.
- Produces: `KNOWN_LOCAL: set[str]`, `HOSTS: tuple[str, ...]`, `check(repo: Path, runner=nixops.run) -> Snapshot`, `format_check(snap: Snapshot) -> str`, `main(argv: list[str] | None = None) -> int`.

**Hinweis für den Implementierer:** `check` bekommt den Kommando-Ausführer als Parameter (`runner`). Genau das macht ihn testbar, ohne `nix` aufzurufen — der Test schiebt eine Funktion unter, die aufgezeichnete Ausgaben zurückgibt.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_cli_check.py
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.cli import check, format_check, KNOWN_LOCAL
from nixup.nixops import Run

MIT_BLOCKER = """these 3 derivations will be built:
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-python3.14-ifcopenshell-0.8.0.drv
  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-ghostty-1.3.1.drv
  /nix/store/cccccccccccccccccccccccccccccccc-system-path.drv
"""
SAUBER = """these 2 derivations will be built:
  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-ghostty-1.3.1.drv
  /nix/store/cccccccccccccccccccccccccccccccc-system-path.drv
"""

def repo_mit_lock(tmp_path, ts):
    (tmp_path / "flake.nix").write_text("{}")
    (tmp_path / "flake.lock").write_text(json.dumps({
        "root": "root",
        "nodes": {"root": {"inputs": {"nixpkgs": "n"}},
                  "n": {"locked": {"lastModified": ts}}},
    }))
    (tmp_path / "blockers.toml").write_text("")
    return tmp_path

def runner_fuer(stderr):
    def r(cmd, cwd=None):
        if "--dry-run" in cmd:
            return Run(code=0, out="", err=stderr)
        return Run(code=0, out="", err="")
    return r

def test_check_meldet_unerwartetes_paket(tmp_path):
    repo = repo_mit_lock(tmp_path, 1788179007)
    snap = check(repo, runner=runner_fuer(MIT_BLOCKER))
    assert "python3.14-ifcopenshell-0.8.0" in snap.unexpected
    assert "ghostty-1.3.1" not in snap.unexpected   # steht in KNOWN_LOCAL

def test_check_ohne_unerwartetes_ist_sauber(tmp_path):
    repo = repo_mit_lock(tmp_path, 1788179007)
    snap = check(repo, runner=runner_fuer(SAUBER))
    assert snap.unexpected == []
    assert snap.update_available is True

def test_check_ignoriert_glue(tmp_path):
    repo = repo_mit_lock(tmp_path, 1788179007)
    snap = check(repo, runner=runner_fuer(SAUBER))
    assert not any("system-path" in n for n in snap.unexpected)

def test_ghostty_ist_als_bekannt_lokal_hinterlegt():
    assert "ghostty" in KNOWN_LOCAL

def test_format_check_nennt_kosten_und_risiko():
    from nixup.state import Snapshot
    s = Snapshot(update_available=True, unexpected=["python3.14-ifcopenshell-0.8.0"],
                 days_behind=13)
    text = format_check(s)
    assert "13" in text
    assert "ifcopenshell" in text
    assert "Risiko" in text

def test_format_check_bei_sauberem_update():
    from nixup.state import Snapshot
    text = format_check(Snapshot(update_available=True, days_behind=2))
    assert "keine Blocker" in text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest -c pytest modules/meo/nixup/tests/test_cli_check.py -v`
Expected: FAIL mit `ModuleNotFoundError: No module named 'nixup.cli'`

- [ ] **Step 3: Write minimal implementation**

```python
# modules/meo/nixup/src/nixup/cli.py
"""nixup — Kommandozeile.

Spec: docs/superpowers/specs/2026-09-15-nixup-update-architecture-design.md
"""
from __future__ import annotations

import argparse
import json
import os
import tempfile
import time
from pathlib import Path

from . import nixops
from .dryrun import classify, parse
from .groups import locked_timestamp, plan_groups
from .register import load as load_register
from .state import Snapshot

HOSTS = ("meo", "meo-work")

# Pakete, die lokal bauen MUESSEN, weil wir sie patchen: ein eigener Patch
# aendert den Derivation-Hash, damit faellt das Paket aus jedem Binary-Cache.
# Sie sind eine Kostenmeldung, kein Risiko.
KNOWN_LOCAL = {"ghostty"}

REPO = Path.home() / "nixos-config"


def _scratch_dir() -> Path:
    """Wegwerf-Verzeichnis, benutzergebunden damit Mehrbenutzer-Kollisionen
    auf /tmp ausgeschlossen sind."""
    return Path(tempfile.gettempdir()) / f"nixup-scratch-{os.getuid()}"


def check(repo: Path, runner=nixops.run) -> Snapshot:
    """Was wuerde ein Update kosten, und was wuerde es brechen?

    Arbeitet auf einer Wegwerf-Kopie: das echte Repo wird nicht angefasst.
    Kompiliert nichts -- die Antwort steht in Sekunden fest.
    """
    repo = Path(repo)
    kopie = nixops.scratch_copy(repo, _scratch_dir())
    runner(nixops.cmd_flake_update(None), cwd=kopie)

    unerwartet: list[str] = []
    erwartet: list[str] = []
    for host in HOSTS:
        r = runner(nixops.cmd_dry_run(host), cwd=kopie)
        e, u = classify(parse(r.err), KNOWN_LOCAL)
        erwartet += e
        unerwartet += u

    lock_alt = json.loads((repo / "flake.lock").read_text())
    ts = locked_timestamp(lock_alt, "nixpkgs") or 0
    tage = int((time.time() - ts) // 86400) if ts else 0

    reg = load_register(repo / "blockers.toml")
    return Snapshot(
        update_available=bool(erwartet or unerwartet),
        unexpected=sorted(set(unerwartet)),
        blockers=sorted(reg),
        releasable=[],
        days_behind=tage,
    )


def format_check(snap: Snapshot) -> str:
    zeilen = []
    if not snap.update_available:
        return "Kein Update verfuegbar — alles auf Stand."
    zeilen.append(f"Update verfuegbar (nixpkgs {snap.days_behind} Tage alt)")
    if snap.unexpected:
        zeilen.append("  Risiko :")
        for n in snap.unexpected:
            zeilen.append(f"           {n} baut unerwartet lokal")
    else:
        zeilen.append("  keine Blocker — `nixup update`")
    return "\n".join(zeilen)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="nixup")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check", help="Was kostet und was bricht ein Update?")
    args = p.parse_args(argv)

    if args.cmd == "check":
        print(format_check(check(REPO)))
        return 0
    return 1
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_check.py -v`
Expected: PASS, 6 Tests

- [ ] **Step 5: Echter Lauf gegen das echte Repo**

Run: `nix shell nixpkgs#python3Packages.tomli-w -c python3 -c "
import sys; sys.path.insert(0, 'modules/meo/nixup/src')
from pathlib import Path
from nixup.cli import check, format_check
print(format_check(check(Path.home()/'nixos-config')))
"`
Expected: Läuft in unter einer Minute durch und meldet entweder „Kein Update verfuegbar" oder eine Kosten-/Risikoliste. **Kompiliert nichts.**

- [ ] **Step 6: Commit**

```bash
git add modules/meo/nixup/src/nixup/cli.py modules/meo/nixup/tests/test_cli_check.py
git commit -m "nixup: Unterbefehl check

Beantwortet auf einer Wegwerf-Kopie in Sekunden, was ein Update kostet und
was es bricht -- die Information, fuer die fu am 15.09. 14 Minuten
kompiliert hat. Der Kommando-Ausfuehrer ist injizierbar, damit die Logik
ohne nix-Aufruf testbar bleibt.

ghostty steht in KNOWN_LOCAL: es wird von uns gepatcht, faellt dadurch aus
jedem Binary-Cache und ist deshalb eine Kostenmeldung, kein Risiko."
```

---

### Task 7: `nixup status` mit Freigabe-Prüfung

**Files:**
- Modify: `modules/meo/nixup/src/nixup/cli.py` (Funktionen `probe_release`, `status`, `format_status` ergänzen; `main` um den Unterbefehl erweitern)
- Test: `modules/meo/nixup/tests/test_cli_status.py`

**Interfaces:**
- Consumes: `register.load`, `nixops.cmd_release_probe`, `dryrun.parse`.
- Produces: `probe_release(package: str, runner=nixops.run) -> str` mit Rückgabewerten `"releasable" | "expensive" | "blocked"`, `status(repo: Path, runner=nixops.run) -> tuple[dict[str, Blocker], dict[str, str]]`, `format_status(register, urteile) -> str`.

**Das ist der Kern gegen Ursache U2.** Bis heute hatte kein Workaround eine Bedingung, unter der er zurückgebaut wird. Der Test ist bewusst nicht die GitHub-API, sondern: *baut oder lädt das Paket am Kanal-Kopf?*

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_cli_status.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.cli import probe_release, status, format_status
from nixup.nixops import Run
from nixup.register import Blocker

GECACHT = """these 1 paths will be fetched (12.0 MiB download, 40.0 MiB unpacked):
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-freecad-wayland-1.1.3
"""
MUESSTE_BAUEN = """these 2 derivations will be built:
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-python3.14-ifcopenshell-0.8.0.drv
  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-freecad-wayland-1.1.3.drv
"""

def runner(stderr, code=0):
    return lambda cmd, cwd=None: Run(code=code, out="", err=stderr)

def test_gecacht_heisst_aufloesbar():
    assert probe_release("freecad-wayland", runner=runner(GECACHT)) == "releasable"

def test_muesste_bauen_heisst_teuer_nicht_aufloesbar():
    assert probe_release("freecad-wayland", runner=runner(MUESSTE_BAUEN)) == "expensive"

def test_eval_fehler_heisst_weiterhin_blockiert():
    r = runner("error: attribute 'freecad-wayland' missing", code=1)
    assert probe_release("freecad-wayland", runner=r) == "blocked"

def test_status_urteilt_je_eintrag(tmp_path):
    (tmp_path / "blockers.toml").write_text('''
[blocker.freecad]
package = "freecad-wayland"
strategy = "fallback"
''')
    reg, urteile = status(tmp_path, runner=runner(GECACHT))
    assert urteile == {"freecad": "releasable"}

def test_status_ohne_register_ist_leer(tmp_path):
    reg, urteile = status(tmp_path, runner=runner(GECACHT))
    assert reg == {} and urteile == {}

def test_status_prueft_nur_fallback_eintraege(tmp_path):
    (tmp_path / "blockers.toml").write_text('''
[blocker.a]
package = "pkg-a"
strategy = "transient"
''')
    reg, urteile = status(tmp_path, runner=runner(GECACHT))
    assert urteile == {}

def test_format_status_nennt_den_aufloese_befehl():
    reg = {"freecad": Blocker(name="freecad", package="freecad-wayland",
                              strategy="fallback", since="2026-09-15",
                              reason="boost 1.91")}
    text = format_status(reg, {"freecad": "releasable"})
    assert "nixup unpin freecad" in text

def test_format_status_bei_weiterhin_blockiert_kein_befehl():
    reg = {"freecad": Blocker(name="freecad", package="freecad-wayland",
                              strategy="fallback", since="2026-09-15")}
    text = format_status(reg, {"freecad": "blocked"})
    assert "nixup unpin" not in text
    assert "blockiert" in text

def test_format_status_leeres_register():
    assert "Keine Blocker" in format_status({}, {})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_status.py -v`
Expected: FAIL mit `ImportError: cannot import name 'probe_release' from 'nixup.cli'`

- [ ] **Step 3: Write minimal implementation**

In `modules/meo/nixup/src/nixup/cli.py` ergänzen (nach `format_check`):

```python
def probe_release(package: str, runner=nixops.run) -> str:
    """Freigabe-Pruefung: baut oder laedt das Paket am Kanal-Kopf?

    'will be fetched' => der Fix ist da UND gecacht        => aufloesbar
    'will be built'   => Fix evtl. da, aber teuer          => Hinweis
    Eval-Fehler       => weiterhin kaputt                  => blockiert

    Bewusst NICHT ueber die GitHub-API: ein Commit kann in master liegen und
    trotzdem nicht im Kanal sein, und ein Paket kann im Kanal sein und
    trotzdem nicht bauen. Dieser Test kann nicht luegen.
    """
    r = runner(nixops.cmd_release_probe(package))
    if r.code != 0:
        return "blocked"
    d = parse(r.err)
    if any(package in n for n in d.to_fetch):
        return "releasable"
    if any(package in n for n in d.to_build):
        return "expensive"
    # Nichts zu tun heisst: liegt bereits im lokalen Store, also brauchbar.
    return "releasable"


def status(repo: Path, runner=nixops.run):
    reg = load_register(Path(repo) / "blockers.toml")
    urteile = {
        name: probe_release(b.package, runner=runner)
        for name, b in reg.items()
        if b.strategy == "fallback"
    }
    return reg, urteile


def format_status(register, urteile) -> str:
    if not register:
        return "Keine Blocker registriert."
    zeilen = ["Blocker-Register:"]
    for name, b in sorted(register.items()):
        urteil = urteile.get(name, "—")
        zeilen.append(f"  {name} ({b.package}, seit {b.since or '?'})")
        if b.reason:
            zeilen.append(f"      Grund : {b.reason.strip().splitlines()[0]}")
        if urteil == "releasable":
            zeilen.append(f"      → Pin ist ueberfluessig: `nixup unpin {name}`")
        elif urteil == "expensive":
            zeilen.append("      → Fix ist da, aber noch nicht gecacht (teurer Neubau)")
        elif urteil == "blocked":
            zeilen.append("      → blockiert weiterhin")
    return "\n".join(zeilen)
```

In `main` den Unterbefehl ergänzen:

```python
    sub.add_parser("status", help="Register, Freigabe-Pruefung, Aktionsliste")
```

und im Dispatch:

```python
    if args.cmd == "status":
        reg, urteile = status(REPO)
        print(format_status(reg, urteile))
        return 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_status.py -v`
Expected: PASS, 9 Tests

- [ ] **Step 5: Echter Lauf — und er muss heute „blockiert" sagen**

Run: `nix shell nixpkgs#python3Packages.tomli-w -c python3 -c "
import sys; sys.path.insert(0, 'modules/meo/nixup/src')
from pathlib import Path
from nixup.cli import status, format_status
reg, u = status(Path.home()/'nixos-config')
print(format_status(reg, u))
"`
Expected: Der Eintrag `freecad` erscheint. Solange `nixos-unstable` den ifcopenshell-Fix nicht enthält, lautet das Urteil **nicht** `releasable`. Sagt es `releasable`, ist der Kanal inzwischen weitergerückt — dann ist das die korrekte Antwort und `nixup unpin freecad` ist fällig.

- [ ] **Step 6: Commit**

```bash
git add modules/meo/nixup/src/nixup/cli.py modules/meo/nixup/tests/test_cli_status.py
git commit -m "nixup: Unterbefehl status mit Freigabe-Pruefung

Das Stueck, das vier Monate gefehlt hat. Jeder Pin bekommt eine maschinell
pruefbare Bedingung, unter der er wieder verschwindet -- und die wird
automatisch nachgeprueft.

Der Test ist bewusst nicht die GitHub-API: ein Commit kann in master liegen
und trotzdem nicht im Kanal sein, und ein Paket kann im Kanal sein und
trotzdem nicht bauen. Gefragt wird stattdessen direkt, ob das Paket am
Kanal-Kopf substituierbar ist."
```

---

### Task 8: `nixup unpin`

**Files:**
- Modify: `modules/meo/nixup/src/nixup/cli.py`
- Test: `modules/meo/nixup/tests/test_cli_unpin.py`

**Interfaces:**
- Consumes: `register.load/save/remove`, `nixops.cmd_build`, `status`.
- Produces: `unpin(repo: Path, name: str, runner=nixops.run, force: bool = False) -> tuple[bool, str]` — Rückgabe `(erfolg, meldung)`.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_cli_unpin.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.cli import unpin
from nixup.nixops import Run
from nixup.register import load

GECACHT = """these 1 paths will be fetched (1.0 MiB download, 2.0 MiB unpacked):
  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-freecad-wayland-1.1.3
"""

def repo(tmp_path):
    (tmp_path / "blockers.toml").write_text('''
[blocker.freecad]
package = "freecad-wayland"
strategy = "fallback"
''')
    return tmp_path

def test_unpin_entfernt_eintrag_wenn_bau_gruen(tmp_path):
    r = repo(tmp_path)
    def runner(cmd, cwd=None):
        return Run(code=0, out="", err=GECACHT)
    ok, meldung = unpin(r, "freecad", runner=runner)
    assert ok
    assert load(r / "blockers.toml") == {}

def test_unpin_behaelt_eintrag_wenn_bau_rot(tmp_path):
    r = repo(tmp_path)
    def runner(cmd, cwd=None):
        if "--dry-run" in cmd:
            return Run(code=0, out="", err=GECACHT)
        return Run(code=1, out="", err="error: builder failed")   # echter Bau rot
    ok, meldung = unpin(r, "freecad", runner=runner)
    assert not ok
    assert "freecad" in load(r / "blockers.toml")
    assert "builder failed" in meldung

def test_unpin_verweigert_wenn_noch_blockiert(tmp_path):
    r = repo(tmp_path)
    runner = lambda cmd, cwd=None: Run(code=1, out="", err="error: attribute missing")
    ok, meldung = unpin(r, "freecad", runner=runner)
    assert not ok
    assert "blockiert" in meldung
    assert "freecad" in load(r / "blockers.toml")

def test_unpin_mit_force_ignoriert_die_freigabe_pruefung(tmp_path):
    r = repo(tmp_path)
    aufrufe = []
    def runner(cmd, cwd=None):
        aufrufe.append(cmd)
        return Run(code=0, out="", err="")
    ok, _ = unpin(r, "freecad", runner=runner, force=True)
    assert ok

def test_unpin_unbekannter_name(tmp_path):
    ok, meldung = unpin(repo(tmp_path), "gibtsnicht",
                        runner=lambda cmd, cwd=None: Run(0, "", ""))
    assert not ok
    assert "gibtsnicht" in meldung
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_unpin.py -v`
Expected: FAIL mit `ImportError: cannot import name 'unpin'`

- [ ] **Step 3: Write minimal implementation**

In `cli.py` ergänzen:

```python
def unpin(repo: Path, name: str, runner=nixops.run, force: bool = False):
    """Pin aufloesen: Eintrag raus, bauen, bei Gruen bleibt es so.

    Bei rotem Bau wird der Eintrag wiederhergestellt -- ein aufgeloester Pin,
    der nicht baut, ist schlimmer als der Pin.
    """
    pfad = Path(repo) / "blockers.toml"
    reg = load_register(pfad)
    if name not in reg:
        return False, f"Kein Registereintrag namens {name!r}."

    eintrag = reg[name]
    if not force:
        urteil = probe_release(eintrag.package, runner=runner)
        if urteil == "blocked":
            return False, f"{name} blockiert weiterhin — Pin bleibt."

    from .register import remove as remove_entry, save as save_register
    save_register(pfad, remove_entry(reg, name))

    for host in HOSTS:
        r = runner(nixops.cmd_build(host), cwd=Path(repo))
        if r.code != 0:
            save_register(pfad, reg)          # zurueckrollen
            letzte = [z for z in r.err.strip().splitlines() if z.strip()]
            return False, "Bau rot, Pin wiederhergestellt:\n" + "\n".join(letzte[-5:])

    return True, f"{name} entpinnt, beide Hosts bauen gruen."
```

`main` erweitern:

```python
    sp = sub.add_parser("unpin", help="Pin aufloesen und bauen")
    sp.add_argument("name")
    sp.add_argument("--force", action="store_true",
                    help="Freigabe-Pruefung ueberspringen")
```

Dispatch:

```python
    if args.cmd == "unpin":
        ok, meldung = unpin(REPO, args.name, force=args.force)
        print(meldung)
        return 0 if ok else 1
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_unpin.py -v`
Expected: PASS, 5 Tests

- [ ] **Step 5: Commit**

```bash
git add modules/meo/nixup/src/nixup/cli.py modules/meo/nixup/tests/test_cli_unpin.py
git commit -m "nixup: Unterbefehl unpin

Loest einen Pin auf und stellt ihn bei rotem Bau wieder her -- ein
aufgeloester Pin der nicht baut ist schlimmer als der Pin. Ohne --force
wird vorher die Freigabe-Pruefung verlangt, damit niemand einen Pin
aufloest, den der Kanal noch nicht eingeholt hat."
```

---

### Task 9: `nixup update` — die Ratsche

**Files:**
- Modify: `modules/meo/nixup/src/nixup/cli.py`
- Test: `modules/meo/nixup/tests/test_cli_update.py`

**Interfaces:**
- Consumes: `groups.plan_groups`, `nixops.cmd_flake_update/cmd_build`, `register.*`.
- Produces: `GroupResult` (dataclass, Felder `group: str`, `ok: bool`, `error: str`), `update(repo, runner=nixops.run, interactive=True, dry_run=False, asker=None) -> list[GroupResult]`, `format_update(results) -> str`.

**Das Herzstück gegen Ursache U1.** Bisher rollte ein rotes Paket alle 16 Inputs zurück, und der nächste Versuch begann bei null. Hier wird jede grüne Gruppe sofort festgeschrieben; eine rote Gruppe wird einzeln zurückgesetzt und blockiert die anderen nicht.

**Wichtig für den Implementierer:** `asker` ist die Rückfrage-Funktion aus Spec 3.5 mit der Signatur `asker(group: str, fehler: str) -> str`, Rückgabe eine von `"pin" | "skip" | "patch" | "drop"`. Im nicht-interaktiven Timer-Lauf wird sie **nie** aufgerufen; dort gilt immer `"skip"`. Pins sind eine menschliche Entscheidung.

- [ ] **Step 1: Write the failing test**

```python
# modules/meo/nixup/tests/test_cli_update.py
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "src"))

from nixup.cli import update, format_update, GroupResult
from nixup.nixops import Run

LOCK = {
    "root": "root",
    "nodes": {
        "root": {"inputs": {"nixpkgs": "n", "home-manager": "hm",
                            "zen-browser": "zb", "awww": "aw"}},
        "n": {"locked": {"lastModified": 1788179007}},
        "hm": {"locked": {"lastModified": 1788179007}},
        "zb": {"locked": {"lastModified": 1788179007}},
        "aw": {"locked": {"lastModified": 1788179007}},
    },
}

def repo(tmp_path):
    (tmp_path / "flake.nix").write_text("{}")
    (tmp_path / "flake.lock").write_text(json.dumps(LOCK))
    (tmp_path / "blockers.toml").write_text("")
    return tmp_path

def runner_factory(rote_gruppen):
    """Baut rot, sobald zuvor eine Gruppe aus `rote_gruppen` aktualisiert wurde."""
    zustand = {"aktuell": None}
    def runner(cmd, cwd=None):
        if cmd[:3] == ["nix", "flake", "update"]:
            zustand["aktuell"] = tuple(cmd[3:])
            return Run(0, "", "")
        if cmd[:2] == ["nix", "build"] and "--dry-run" not in cmd:
            eingaben = zustand["aktuell"] or ()
            if any(i in rote_gruppen for i in eingaben):
                return Run(1, "", "error: builder failed for ifcopenshell")
            return Run(0, "", "")
        if cmd[:2] == ["git"]:
            return Run(0, "", "")
        return Run(0, "", "")
    return runner

def test_alle_gruen_alle_festgeschrieben(tmp_path):
    ergebnisse = update(repo(tmp_path), runner=runner_factory(set()), interactive=False)
    assert all(e.ok for e in ergebnisse)
    assert {e.group for e in ergebnisse} >= {"core", "zen-browser", "awww"}

def test_eine_rote_gruppe_blockiert_die_anderen_nicht(tmp_path):
    # DAS ist der Kern: core faellt aus, die Blaetter kommen trotzdem durch.
    ergebnisse = update(repo(tmp_path), runner=runner_factory({"nixpkgs"}), interactive=False)
    nach_name = {e.group: e for e in ergebnisse}
    assert nach_name["core"].ok is False
    assert nach_name["zen-browser"].ok is True
    assert nach_name["awww"].ok is True

def test_rote_gruppe_traegt_die_fehlermeldung(tmp_path):
    ergebnisse = update(repo(tmp_path), runner=runner_factory({"nixpkgs"}), interactive=False)
    core = [e for e in ergebnisse if e.group == "core"][0]
    assert "ifcopenshell" in core.error

def test_nicht_interaktiv_fragt_nie(tmp_path):
    def asker(group, fehler):
        raise AssertionError("im Timer-Lauf darf nicht gefragt werden")
    update(repo(tmp_path), runner=runner_factory({"nixpkgs"}),
           interactive=False, asker=asker)

def test_nicht_interaktiv_pinnt_nie(tmp_path):
    from nixup.register import load
    r = repo(tmp_path)
    update(r, runner=runner_factory({"nixpkgs"}), interactive=False)
    assert load(r / "blockers.toml") == {}   # Pins sind Menschenentscheidung

def test_dry_run_committet_nicht(tmp_path):
    aufrufe = []
    def runner(cmd, cwd=None):
        aufrufe.append(cmd)
        return Run(0, "", "")
    update(repo(tmp_path), runner=runner, interactive=False, dry_run=True)
    assert not any(c[:2] == ["git", "commit"] for c in aufrufe)

def test_normaler_lauf_committet_je_gruene_gruppe(tmp_path):
    aufrufe = []
    def runner(cmd, cwd=None):
        aufrufe.append(cmd)
        return Run(0, "", "")
    ergebnisse = update(repo(tmp_path), runner=runner, interactive=False)
    commits = [c for c in aufrufe if c[:2] == ["git", "commit"]]
    assert len(commits) == len([e for e in ergebnisse if e.ok])

def test_format_update_zeigt_gruen_und_rot():
    text = format_update([GroupResult("core", False, "boom"),
                          GroupResult("awww", True, "")])
    assert "core" in text and "awww" in text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_update.py -v`
Expected: FAIL mit `ImportError: cannot import name 'update'`

- [ ] **Step 3: Write minimal implementation**

In `cli.py` ergänzen:

```python
from dataclasses import dataclass


@dataclass
class GroupResult:
    group: str
    ok: bool
    error: str = ""


def _git(repo: Path, args: list[str], runner) -> nixops.Run:
    return runner(["git"] + args, cwd=repo)


def update(repo: Path, runner=nixops.run, interactive: bool = True,
           dry_run: bool = False, asker=None) -> list[GroupResult]:
    """Die Ratsche: je Gruppe einzeln aktualisieren, bauen, gruen festschreiben.

    Der Unterschied zum alten `fu`: dort rollte ein rotes Paket ALLE Inputs
    zurueck, und der naechste Versuch begann bei null. Deshalb konvergierte
    nichts. Hier bleibt eine rote Gruppe auf ihrem letzten guten Stand und
    blockiert die anderen fuenfzehn nicht.
    """
    repo = Path(repo)
    lock = json.loads((repo / "flake.lock").read_text())
    ergebnisse: list[GroupResult] = []

    for gruppe in plan_groups(lock):
        runner(nixops.cmd_flake_update(gruppe.inputs), cwd=repo)

        fehler = ""
        for host in HOSTS:
            r = runner(nixops.cmd_build(host), cwd=repo)
            if r.code != 0:
                zeilen = [z for z in r.err.strip().splitlines() if z.strip()]
                fehler = "\n".join(zeilen[-8:])
                break

        if fehler:
            # Nur DIESE Gruppe zuruecksetzen, nicht den ganzen Lock.
            _git(repo, ["checkout", "HEAD", "--", "flake.lock"], runner)
            ergebnisse.append(GroupResult(gruppe.name, False, fehler))
            # Im Timer-Lauf wird nie gefragt und nie gepinnt (Spec 3.5).
            if interactive and asker is not None:
                asker(gruppe.name, fehler)
            continue

        if not dry_run:
            _git(repo, ["add", "flake.lock"], runner)
            _git(repo, ["commit", "-m",
                        f"flake: Gruppe {gruppe.name} aktualisiert (nixup)"], runner)
        ergebnisse.append(GroupResult(gruppe.name, True, ""))

    return ergebnisse


def format_update(results: list[GroupResult]) -> str:
    zeilen = []
    gruen = [r for r in results if r.ok]
    rot = [r for r in results if not r.ok]
    zeilen.append(f"{len(gruen)} von {len(results)} Gruppen aktualisiert.")
    for r in gruen:
        zeilen.append(f"  ok   {r.group}")
    for r in rot:
        zeilen.append(f"  ROT  {r.group}")
        for z in r.error.splitlines()[-3:]:
            zeilen.append(f"         {z}")
    return "\n".join(zeilen)
```

`main` erweitern:

```python
    sp = sub.add_parser("update", help="Ratsche: Gruppen einzeln aktualisieren")
    sp.add_argument("--dry-run", action="store_true",
                    help="alles ausser committen")
    sp.add_argument("--non-interactive", action="store_true",
                    help="nie fragen, nie pinnen (Timer-Modus)")
```

Dispatch:

```python
    if args.cmd == "update":
        ergebnisse = update(REPO, interactive=not args.non_interactive,
                            dry_run=args.dry_run)
        print(format_update(ergebnisse))
        return 0 if all(e.ok for e in ergebnisse) else 1
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix shell nixpkgs#python3Packages.pytest nixpkgs#python3Packages.tomli-w -c pytest modules/meo/nixup/tests/test_cli_update.py -v`
Expected: PASS, 8 Tests

- [ ] **Step 5: Probelauf ohne Festschreiben gegen das echte Repo**

```bash
git status --short            # MUSS leer sein, sonst abbrechen
nix shell nixpkgs#python3Packages.tomli-w -c python3 -c "
import sys; sys.path.insert(0, 'modules/meo/nixup/src')
from pathlib import Path
from nixup.cli import update, format_update
print(format_update(update(Path.home()/'nixos-config',
                           interactive=False, dry_run=True)))
"
git status --short            # MUSS wieder leer sein
```
Expected: Eine Zeile je Gruppe. Der Arbeitsbaum ist hinterher unverändert — `--dry-run` schreibt nichts fest, und rote Gruppen setzen `flake.lock` zurück.

- [ ] **Step 6: Commit**

```bash
git add modules/meo/nixup/src/nixup/cli.py modules/meo/nixup/tests/test_cli_update.py
git commit -m "nixup: Unterbefehl update -- die Ratsche

Der Kern gegen Ursache U1. Bisher rollte ein rotes Paket alle 16 Inputs
zurueck und der naechste Versuch begann bei null -- deshalb gab es seit
dem 18.05. genau einen gemergten Update-PR. Jetzt wird je Gruppe einzeln
aktualisiert, gebaut und bei Gruen sofort festgeschrieben; eine rote
Gruppe faellt auf ihren letzten guten Stand zurueck und blockiert die
anderen nicht.

Im nicht-interaktiven Timer-Lauf wird nie gefragt und nie gepinnt: ein Pin
ist eine Nutzungsentscheidung und bleibt beim Menschen."
```

---

### Task 10: Das Register treibt Nix

**Files:**
- Create: `modules/meo/fallback-overlay.nix`
- Modify: `hosts/meo/host-packages.nix` (die fest verdrahtete `inputs.nixpkgs-fallback`-Zeile ersetzen)
- Modify: `flake.nix` (Overlay in `nixpkgs.overlays` einhängen)

**Interfaces:**
- Consumes: `blockers.toml`, Input `nixpkgs-fallback`.
- Produces: ein Overlay, das jedes Paket mit `strategy = "fallback"` aus `nixpkgs-fallback` bezieht.

**Warum das zählt:** Bis hierhin ist `blockers.toml` reine Dokumentation, und der FreeCAD-Pin steht fest verdrahtet in `host-packages.nix`. Erst mit diesem Task wird das Register wirksam — und erst dann kann `nixup unpin` überhaupt etwas bewirken.

- [ ] **Step 1: Rot-Nachweis vorbereiten — der Ist-Zustand festhalten**

```bash
nix eval --raw ".#nixosConfigurations.meo.pkgs.freecad-wayland.outPath" > /tmp/freecad-vorher.txt
cat /tmp/freecad-vorher.txt
```
Expected: Ein Store-Pfad. Notieren — er muss nach dem Umbau **derselbe** sein, sonst routet das Overlay falsch.

- [ ] **Step 2: Overlay schreiben**

```nix
# modules/meo/fallback-overlay.nix
#
# Routet Pakete aus blockers.toml auf den Rueckfall-Pin nixpkgs-fallback.
#
# Der Sinn: das Register ist die einzige Quelle der Wahrheit. Ein fest
# verdrahteter Pin in host-packages.nix kann von `nixup unpin` nicht
# aufgeloest werden -- und genau so ist der Vorgaenger-Pin (nixpkgs-freecad)
# vier Monate unbemerkt liegengeblieben.
#
# Spec: docs/superpowers/specs/2026-09-15-nixup-update-architecture-design.md
{
  lib,
  fallbackPkgs,
  registerFile,
}: final: prev: let
  register = (builtins.fromTOML (builtins.readFile registerFile)).blocker or {};
  gepinnt = lib.filter (b: b.strategy or "" == "fallback") (builtins.attrValues register);
in
  builtins.listToAttrs (
    map (b: lib.nameValuePair b.package fallbackPkgs.${b.package}) gepinnt
  )
```

- [ ] **Step 3: In flake.nix einhängen**

In der Stelle, an der `pkgs` für `mkNixosConfig` gebaut wird, das Overlay ergänzen:

```nix
overlays = [
  (import ./modules/meo/fallback-overlay.nix {
    inherit lib;
    fallbackPkgs = inputs.nixpkgs-fallback.legacyPackages.${system};
    registerFile = ./blockers.toml;
  })
  # ... bestehende Overlays unveraendert darunter
];
```

- [ ] **Step 4: host-packages.nix auf das Overlay umstellen**

Ersetzen:
```nix
    # Aus dem Rueckfall-Pin nixpkgs-fallback (34ab990, 2026-08-31), weil
    # ifcopenshell 0.8.0 am Kanal-Kopf nicht gegen boost 1.91 baut.
    # Registriert in blockers.toml -> dort steht die Freigabe-Bedingung.
    inputs.nixpkgs-fallback.legacyPackages.${pkgs.system}.freecad-wayland
```
durch:
```nix
    # Kommt regulaer aus pkgs. Ob es aus nixpkgs oder aus dem Rueckfall-Pin
    # stammt, entscheidet blockers.toml ueber fallback-overlay.nix.
    freecad-wayland
```

- [ ] **Step 5: Nachweisen, dass das Overlay tatsächlich routet**

```bash
nix eval --raw ".#nixosConfigurations.meo.pkgs.freecad-wayland.outPath" > /tmp/freecad-nachher.txt
diff /tmp/freecad-vorher.txt /tmp/freecad-nachher.txt && echo ">>> IDENTISCH — Overlay routet korrekt <<<"
```
Expected: `IDENTISCH`. Weicht der Pfad ab, kommt FreeCAD wieder vom Kanal-Kopf und der Pin ist wirkungslos.

- [ ] **Step 6: Rot-Nachweis — das Overlay muss auch abschalten können**

```bash
cp blockers.toml /tmp/blockers-backup.toml
python3 - <<'EOF'
import pathlib, re
p = pathlib.Path("blockers.toml")
p.write_text(p.read_text().replace('strategy = "fallback"', 'strategy = "transient"'))
EOF
nix eval --raw ".#nixosConfigurations.meo.pkgs.freecad-wayland.outPath" > /tmp/freecad-ohne-pin.txt
diff /tmp/freecad-vorher.txt /tmp/freecad-ohne-pin.txt || echo ">>> UNTERSCHIEDLICH — das Register steuert wirklich <<<"
cp /tmp/blockers-backup.toml blockers.toml
```
Expected: `UNTERSCHIEDLICH`. Sind beide gleich, liest das Overlay das Register nicht und der Test wäre wertlos gewesen.

- [ ] **Step 7: Beide Hosts bauen**

Run: `nix build ".#nixosConfigurations.meo.config.system.build.toplevel" --no-link && nix build ".#nixosConfigurations.meo-work.config.system.build.toplevel" --no-link`
Expected: Beide grün.

- [ ] **Step 8: Commit**

```bash
git add modules/meo/fallback-overlay.nix flake.nix hosts/meo/host-packages.nix
git commit -m "nixup: blockers.toml treibt jetzt Nix

Bisher war das Register reine Dokumentation und der FreeCAD-Pin stand fest
verdrahtet in host-packages.nix -- also genau da, wo `nixup unpin` ihn nicht
erreichen kann. Das Overlay liest jetzt blockers.toml und routet jedes
Paket mit strategy = fallback auf nixpkgs-fallback.

Nachgewiesen: freecad-wayland.outPath ist vor und nach dem Umbau identisch,
und aendert sich, sobald die strategy im Register auf transient gesetzt wird."
```

---

### Task 11: Paketierung, Timer und Benachrichtigungen

**Files:**
- Create: `modules/meo/nixup/src/nixup/__main__.py`
- Create: `modules/meo/nixup/default.nix`
- Modify: `modules/meo/nixup/src/nixup/cli.py` (Unterbefehl-Flags `--quiet`/`--notify`)
- Modify: `modules/meo/default.nix` (Modul importieren)

**Interfaces:**
- Consumes: `state.transitions/load_state/save_state`, `check`, `status`.
- Produces: ausführbares `nixup` im `PATH`, systemd-User-Service `nixup-check` und -Timer.

- [ ] **Step 1: Einstiegspunkt anlegen**

```python
# modules/meo/nixup/src/nixup/__main__.py
import sys

from .cli import main

sys.exit(main())
```

- [ ] **Step 2: Benachrichtigungs-Pfad in cli.py ergänzen**

```python
STATE_FILE = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "nixup" / "last.json"


def notify_run(repo: Path, runner=nixops.run, notifier=None) -> list:
    """Timer-Lauf: pruefen, mit dem letzten Zustand vergleichen, nur bei
    Aenderung melden.

    Ein Timer, der taeglich dasselbe meldet, wird weggeklickt und ist danach
    wertlos. Deshalb sind die Uebergaenge die Einheit, nicht der Zustand.
    """
    from .state import load_state, save_state, transitions

    snap = check(repo, runner=runner)
    _, urteile = status(repo, runner=runner)
    snap.releasable = sorted(n for n, u in urteile.items() if u == "releasable")

    vorher = load_state(STATE_FILE)
    meldungen = transitions(vorher, snap)
    save_state(STATE_FILE, snap)

    if notifier is None:
        def notifier(n):
            runner(["notify-send", "nixup", n.text])
    for n in meldungen:
        notifier(n)
    return meldungen
```

`main` erweitern — beim `check`-Parser:

```python
    cp = sub.add_parser("check", help="Was kostet und was bricht ein Update?")
    cp.add_argument("--quiet", action="store_true", help="nichts auf stdout")
    cp.add_argument("--notify", action="store_true",
                    help="bei Zustandsaenderung benachrichtigen (Timer-Modus)")
```

Dispatch für `check` ersetzen durch:

```python
    if args.cmd == "check":
        if args.notify:
            meldungen = notify_run(REPO)
            if not args.quiet:
                for m in meldungen:
                    print(m.text)
            return 0
        snap = check(REPO)
        if not args.quiet:
            print(format_check(snap))
        return 0
```

- [ ] **Step 3: Nix-Modul schreiben**

```nix
# modules/meo/nixup/default.nix
#
# nixup -- Update-Ratsche mit Blocker-Register.
# Spec : docs/superpowers/specs/2026-09-15-nixup-update-architecture-design.md
# Plan : docs/superpowers/plans/2026-09-16-nixup-v1-kern.md
{pkgs, ...}: let
  pythonEnv = pkgs.python3.withPackages (ps: [ps.tomli-w]);

  nixup = pkgs.writeShellApplication {
    name = "nixup";
    runtimeInputs = [pythonEnv pkgs.nix pkgs.git pkgs.libnotify pkgs.coreutils];
    text = ''
      export PYTHONPATH="${./src}:''${PYTHONPATH:-}"
      exec python3 -m nixup "$@"
    '';
  };
in {
  home.packages = [nixup];

  systemd.user.services.nixup-check = {
    Unit.Description = "nixup: Update-Lage pruefen und bei Aenderung melden";
    Service = {
      Type = "oneshot";
      # --notify meldet NUR bei Zustandsaenderung. --quiet haelt das
      # Journal frei, die Meldung geht an notify-send.
      ExecStart = "${nixup}/bin/nixup check --quiet --notify";
    };
  };

  systemd.user.timers.nixup-check = {
    Unit.Description = "Timer: nixup-Lagepruefung";
    Timer = {
      OnCalendar = "*-*-* 10:00:00";
      Persistent = true; # verpasste Laeufe nach Standby/Aus nachholen
      RandomizedDelaySec = "45m";
    };
    Install.WantedBy = ["timers.target"];
  };
}
```

- [ ] **Step 4: Modul importieren**

In `modules/meo/default.nix` zur Importliste hinzufügen: `./nixup`

- [ ] **Step 5: Bauen und aktivieren lassen**

```bash
nix build ".#nixosConfigurations.meo.config.system.build.toplevel" --no-link
nix build ".#nixosConfigurations.meo-work.config.system.build.toplevel" --no-link
```
Expected: Beide grün. (Aktivieren macht der Benutzer selbst mit `nh os switch --hostname meo` — `nixup` aktiviert nie.)

- [ ] **Step 6: Nach der Aktivierung prüfen, dass der Timer wirklich läuft**

```bash
systemctl --user list-timers nixup-check --all
nixup check
nixup status
```
Expected: Der Timer ist gelistet mit einem Termin in der Zukunft. `nixup check` und `nixup status` laufen ohne Traceback.

- [ ] **Step 7: Commit**

```bash
git add modules/meo/nixup/default.nix modules/meo/nixup/src/nixup/__main__.py modules/meo/nixup/src/nixup/cli.py modules/meo/default.nix
git commit -m "nixup: Paketierung, Timer und Benachrichtigungen

Taeglicher User-Timer mit Persistent=true (holt Laeufe nach Standby nach)
und RandomizedDelaySec. Gemeldet wird ausschliesslich bei Zustandsaenderung
-- ein Timer der taeglich dasselbe sagt wird weggeklickt und ist danach
wertlos, genau wie der alte Waechter mit seinem dauerhaften 'GESAMT: ok'."
```

---

### Task 12: Rückbau der toten Automation

**Files:**
- Delete: `.github/workflows/flake-update.yml`, `.github/workflows/automerge.yml`, `.github/workflows/build.yml`
- Modify: `modules/upstream/home/zsh/default.nix` (Funktion `fu` ersetzen)
- Modify: `modules/meo/automation-health.nix` (Check `lock-age` entfernen)

**Begründung je Datei:** `flake-update.yml` und `automerge.yml` haben seit dem 18.05. genau einen PR durchgebracht; ihre Checks laufen wegen der `GITHUB_TOKEN`-Regel grundsätzlich nie (drei Runs à `0s`, alle `action_required`). `build.yml` lief am 15.09. zweimal in den 60-Minuten-Timeout, weil das gepatchte ghostty ohne beschreibbaren Cache jedes Mal neu kompiliert. `lock-age` misst absolutes Alter gegen 21 Tage statt Abstand zum Kanal und meldete deshalb „ok" bei totem Prozess.

- [ ] **Step 1: Ist-Zustand für die Commit-Message festhalten**

```bash
gh run list --limit 20 > /tmp/runs-vorher.txt
gh pr view 28 --json number,title,createdAt,statusCheckRollup > /tmp/pr28.json
cat /tmp/pr28.json
```
Expected: PR #28 ohne Checks. Beides in die Commit-Message aufnehmen.

- [ ] **Step 2: Workflows entfernen**

```bash
git rm .github/workflows/flake-update.yml .github/workflows/automerge.yml .github/workflows/build.yml
```

- [ ] **Step 3: `fu` durch `nixup update` ersetzen**

In `modules/upstream/home/zsh/default.nix` den kompletten `fu()`-Block ersetzen durch:

```bash
      # fu: ersetzt durch `nixup update` (Ratsche pro Input-Gruppe).
      # Das alte fu rollte bei einem roten Paket ALLE Inputs zurueck --
      # deshalb kam seit dem 18.05. genau ein Update durch.
      # Spec: docs/superpowers/specs/2026-09-15-nixup-update-architecture-design.md
      fu() {
        echo "→ fu ist abgeloest. Nutze:"
        echo "    nixup check    — was kostet und was bricht ein Update?"
        echo "    nixup update   — Ratsche: Gruppen einzeln, gruen wird festgeschrieben"
        echo "    nixup status   — Blocker-Register und Freigabe-Pruefung"
        return 1
      }
```

`fr` bleibt **unverändert**.

- [ ] **Step 4: `lock-age` aus dem Wächter entfernen**

In `modules/meo/automation-health.nix` den kompletten `lock-age`-Block streichen (alle vier `add_check lock-age`-Aufrufe und die zugehörige Logik). Die Checks `git-sync`, `failed-units`, `nas-mounts`, `gc-timer`, `disk-space` bleiben unangetastet.

Darüber einen Kommentar setzen:
```bash
      # lock-age ENTFERNT 2026-09-16: mass absolutes Alter des Lock-Eintrags
      # gegen eine 21-Tage-Schwelle und meldete deshalb "ok", waehrend die
      # Update-Kette vier Monate tot war. Der richtige Messwert ist der
      # Abstand zum Kanal -- den liefert `nixup status`.
```

- [ ] **Step 5: Prüfen, dass der Wächter noch läuft**

```bash
nix build ".#nixosConfigurations.meo.config.system.build.toplevel" --no-link
nix build ".#nixosConfigurations.meo-work.config.system.build.toplevel" --no-link
```
Expected: Beide grün.

- [ ] **Step 6: PR #28 schließen und Branch löschen**

```bash
gh pr close 28 --comment "Abgeloest durch die lokale nixup-Ratsche. Die Checks dieses PRs sind nie gelaufen: GITHUB_TOKEN-erzeugte PRs triggern keine Workflows, und GITHUB_TOKEN-Pushes ebenfalls nicht -- der Workaround in build.yml konnte deshalb nicht greifen."
git push origin --delete update_flake_lock_action
```

- [ ] **Step 7: Commit**

```bash
git add -A .github modules/upstream/home/zsh/default.nix modules/meo/automation-health.nix
git commit -m "ci: tote Update-Automation zurueckgebaut

flake-update.yml + automerge.yml: seit 18.05. genau ein durchgebrachter PR
(#6). Ihre Checks koennen prinzipiell nicht laufen -- GITHUB_TOKEN-erzeugte
PRs triggern keine Workflows, GITHUB_TOKEN-Pushes ebenfalls nicht, womit
der Branch-Workaround in build.yml wirkungslos war. Drei Runs a 0s,
alle action_required.

build.yml: lief am 15.09. zweimal in timeout-minutes: 60 (1h01m, 1h16m),
weil das gepatchte ghostty ohne beschreibbaren Cache jedes Mal neu baut.
Die Ratsche baut beide Hosts lokal, wo der Store sie schon hat.

lock-age im Waechter: mass absolutes Alter statt Kanal-Abstand und meldete
'GESAMT: ok' bei toter Kette. Ersetzt durch nixup status.

lint.yml, vulnix.yml, hyprland-tracker.yml, track-zaneyos.yml bleiben.
fr bleibt unveraendert."
```

---

### Task 13: ghostty-Bauzeit messen und entscheiden

**Files:**
- Modify (nur bei eindeutigem Messergebnis): `modules/meo/ghostty-scroll-fix.nix`

**Hintergrund:** ghostty ist mit `doCheck = 1` gebaut (verifiziert) und fällt wegen unseres Patches aus jedem Binary-Cache. Es ist damit der einzige echte Dauerkostenpunkt jedes Updates. Ob `doCheck = false` lohnt, wird **gemessen, nicht geschätzt** — mein bisheriger Eindruck aus dem `nh`-Log war nicht belastbar, weil `nh` die Gesamtzeit anzeigt und nicht die Phasendauer.

- [ ] **Step 1: Bauzeit mit Tests messen**

```bash
nix build --rebuild --no-link \
  ".#nixosConfigurations.meo.pkgs.ghostty" -L 2>&1 \
  | ts '[%H:%M:%S]' > /tmp/ghostty-mit-tests.log
grep -nE "checkPhase|installPhase|buildPhase" /tmp/ghostty-mit-tests.log
```
(Braucht `moreutils` für `ts`: `nix shell nixpkgs#moreutils -c ...`)
Expected: Zeitstempel für den Beginn von `buildPhase`, `checkPhase` und `installPhase`. Differenz `checkPhase → installPhase` ist die reine Testzeit.

- [ ] **Step 2: Entscheidung anhand der Zahl**

- Testzeit **über 50 %** der Gesamtzeit → Schritt 3 ausführen.
- Testzeit **unter 50 %** → Task hier beenden und das Ergebnis im Commit von Task 12 als Notiz festhalten. `doCheck = false` lohnt dann nicht und macht den Bau nur blinder.

- [ ] **Step 3: Nur bei über 50 % — doCheck abschalten**

In `modules/meo/ghostty-scroll-fix.nix`:

```nix
  ghostty = prev.ghostty.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/ghostty-hires-scroll.patch ];

    # doCheck abgeschaltet 2026-09-16 nach Messung: die Zig-Test-Suite macht
    # <ANTEIL> % der Bauzeit aus, und weil unser Patch den Derivation-Hash
    # aendert, faellt ghostty aus jedem Binary-Cache -- diese Zeit faellt bei
    # JEDEM Update an. Der Patch betrifft ausschliesslich scrollCallback()
    # in Surface.zig.
    #
    # ACHTUNG: das ist eine bewusste Menschenentscheidung an einer einzelnen
    # Stelle. Der Reparatur-Agent darf doCheck NIE als Reparatur setzen
    # (Spec 3.8) -- Tests abschalten damit etwas baut ist das Loeschen des
    # Zeugen.
    doCheck = false;
  });
```

`<ANTEIL>` durch die gemessene Zahl aus Schritt 1 ersetzen.

- [ ] **Step 4: Gegenmessung**

```bash
nix build --rebuild --no-link ".#nixosConfigurations.meo.pkgs.ghostty" -L 2>&1 \
  | ts '[%H:%M:%S]' > /tmp/ghostty-ohne-tests.log
tail -1 /tmp/ghostty-mit-tests.log; tail -1 /tmp/ghostty-ohne-tests.log
```
Expected: Die zweite Zeit liegt messbar unter der ersten. Tut sie das nicht, `doCheck = false` wieder entfernen — dann war die Annahme falsch.

- [ ] **Step 5: Commit**

```bash
git add modules/meo/ghostty-scroll-fix.nix
git commit -m "ghostty: doCheck nach Messung abgeschaltet

Gemessen statt geschaetzt: Testzeit <VORHER> -> <NACHHER>. Weil unser Patch
den Derivation-Hash aendert, faellt ghostty aus jedem Binary-Cache und diese
Zeit faellt bei JEDEM Update an.

Bewusste Einzelfallentscheidung. Der Reparatur-Agent darf doCheck nie als
Reparatur setzen (Spec 3.8)."
```

---

## Self-Review

**Spec-Abdeckung**

| Spec | Task |
|---|---|
| 3.1 Isolations-Pin, ein Input statt N | 10 (Overlay); Input selbst bereits gesetzt |
| 3.2 Input-Gruppen | 3 |
| 3.3 `check` / `update` / `status` / `unpin` | 6 / 9 / 7 / 8 |
| 3.4 Freigabe-Prüfung | 7 |
| 3.5 Verhalten bei Fehlschlag | 9 (`asker`-Schnittstelle, Timer-Lauf pinnt nie) |
| 3.6 Register-Schema | 1 |
| 3.7 Erinnerungen | 4 (Übergänge) + 11 (Timer, notify-send) |
| 3.8 / 3.8.1 Reparatur-Agent | **bewusst ausgeklammert** — eigener Plan |
| 3.9 Release-Wächter | **bewusst ausgeklammert** — eigener Plan |
| 4 Rückbau | 12 |
| 5.1 FreeCAD-Pin | bereits erledigt (Commit `b1b24f6`) |
| 5.2 ghostty-Messung | 13 |
| 6 Testbarkeit | 1–9, alle reinen Module mit pytest |

**Lücke, die diese Durchsicht aufgedeckt hat:** Spec 3.5 beschreibt vier Varianten bei Fehlschlag (Pin / Überspringen / Patch / Entfernen). Task 9 legt die `asker`-Schnittstelle an und implementiert „Überspringen", aber die drei anderen Varianten sind in v1 **nicht** ausimplementiert. Das ist vertretbar — sie gehören logisch zum Reparatur-Agenten, der dieselben Entscheidungen automatisch trifft — muss aber benannt sein, statt stillschweigend zu fehlen. Der Folgeplan implementiert `asker` vollständig.

**Platzhalter-Prüfung:** `<ANTEIL>`, `<VORHER>`, `<NACHHER>` in Task 13 sind bewusst Messwerte, die erst beim Ausführen entstehen — Schritt 1 sagt, wie sie ermittelt werden. Keine „TBD", kein „implement later", kein „ähnlich wie Task N".

**Typ-Konsistenz geprüft:** `Blocker` (Task 1) wird in 7/8 mit denselben Feldnamen verwendet. `Snapshot` (Task 4) wird von `check` (6) erzeugt und in 11 befüllt — Feld `releasable` wird erst in 11 gesetzt, in 6 bewusst leer gelassen. `Run` (Task 5) wird in allen Test-Doubles mit `(code, out, err)` konstruiert. `runner`-Signatur ist überall `(cmd, cwd=None)`.

## Offene Punkte aus der Spec

Beide betreffen ausschliesslich den Folgeplan (Reparatur-Agent) und blockieren v1 nicht:
- Anlaufbudget je Blocker (Vorschlag: 3) und Token-Budget je Timer-Lauf.
- Verhalten, wenn nur `meo-work` bricht — der Timer läuft vorerst nur auf `meo`.
