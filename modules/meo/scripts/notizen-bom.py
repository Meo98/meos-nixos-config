#!/usr/bin/env python3
"""notizen-bom: Stücklisten aus KiCad-Schaltplänen in die Notizen (~/Notizen) schreiben.

Ersetzt die frühere Notion-Synchronisation (scripts/sync_notion.py der Projektvorlage).
Für jede Projektnotiz mit Frontmatter-Zeile `ordner:` werden alle KiCad-Schaltpläne
unter diesem Ordner gelesen und
  1. in der Projektnotiz der Abschnitt "## Stückliste" zwischen den Markern
     <!-- notizen-bom:start --> und <!-- notizen-bom:end --> neu geschrieben,
  2. die Bauteil-Bibliothek Wissen/Bauteile.md über alle Projekte neu erzeugt.
Ausserhalb der Marker wird nichts verändert. Dateien werden nur geschrieben, wenn
sich ihr Inhalt ändert (kein unnötiger Syncthing-Verkehr).

Aufruf:  notizen-bom [--notizen DIR] [--dry-run] [-v]
"""

import argparse
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

START = "<!-- notizen-bom:start -->"
END = "<!-- notizen-bom:end -->"
HEADING = "## Stückliste"

# Ordner, die nie durchsucht werden (Backups, Versionsverwaltung, Build-Reste)
SKIP_DIRS = {".git", ".history", ".venv", "venv", "node_modules", "build", "target",
             ".stversions", "__pycache__"}

# Typ-Erkennung wie im alten sync_notion.py, erweitert
TYPE_MAP = [
    ("Device:R", "Widerstand"), ("Device:C", "Kondensator"), ("Device:L", "Induktivität"),
    ("Device:LED", "LED"), ("Device:D", "Diode"), ("Device:Crystal", "Quarz"),
    ("Device:Fuse", "Sicherung"), ("Device:Polyfuse", "Sicherung"),
    ("Transistor_FET", "MOSFET"), ("Transistor_BJT", "Transistor"), ("Transistor", "Transistor"),
    ("Connector", "Steckverbinder"), ("Switch", "Schalter"), ("Relay", "Relais"),
    ("Pico", "Mikrocontroller"), ("RP2040", "Mikrocontroller"), ("RP2350", "Mikrocontroller"),
    ("ESP32", "Mikrocontroller"), ("MCU_", "Mikrocontroller"),
    ("Regulator", "Spannungsregler"), ("L78", "Spannungsregler"), ("AMS1117", "Spannungsregler"),
    ("DRV", "IC / Treiber"), ("Driver", "IC / Treiber"), ("TB6612", "Motortreiber"),
    ("PC817", "Optokoppler"), ("Isolator", "Optokoppler"), ("IRF", "MOSFET"),
    ("BTS", "High-Side Switch"), ("1.5KE", "TVS-Diode"), ("TVS", "TVS-Diode"),
    ("TEST_PAD", "Testpunkt"), ("TestPoint", "Testpunkt"), ("Sensor", "Sensor"), ("Amplifier", "Verstärker"), ("Mechanical", "Mechanik"),
]
# Für diese Typen ist der Wert kein Bauteilname (10k, 100n …) → keine eigene Bauteil-Notiz
GENERIC_TYPES = {"Widerstand", "Kondensator", "Induktivität", "LED", "Steckverbinder",
                 "Schalter", "Sicherung", "Mechanik", "Testpunkt", "Lötbrücke"}
MF_KEYS = ("MF", "Manufacturer", "Hersteller", "MANUFACTURER")
MPN_KEYS = ("MPN", "Manufacturer Part Number", "Manufacturer_Part_Number", "Teilenummer",
            "LCSC", "LCSC Part", "Mouser", "Mouser Part Number", "Digikey")


# ── S-Ausdrücke (KiCad-Dateiformat) ──────────────────────────────────────────

def parse_sexpr(text):
    """Minimaler, robuster S-Ausdruck-Parser: Listen und Atome (Strings ohne Quotes)."""
    tokens = re.finditer(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()"]+', text)
    stack = [[]]
    for m in tokens:
        t = m.group(0)
        if t == "(":
            stack.append([])
        elif t == ")":
            if len(stack) == 1:
                raise ValueError("unbalancierte Klammern")
            done = stack.pop()
            stack[-1].append(done)
        elif t.startswith('"'):
            # KiCad maskiert in Strings nur \" \\ und \n
            stack[-1].append(re.sub(r'\\(.)', lambda m: "\n" if m.group(1) == "n" else m.group(1), t[1:-1]))
        else:
            stack[-1].append(t)
    if len(stack) != 1:
        raise ValueError("unvollständige Datei")
    return stack[0]


def children(node, head):
    return [c for c in node if isinstance(c, list) and c and c[0] == head]


def first(node, head):
    found = children(node, head)
    return found[0] if found else None


def flag(node, head):
    n = first(node, head)
    return bool(n) and len(n) > 1 and n[1] == "yes"


def symbols_of(path):
    """Platzierte Symbole eines Schaltplans als Dicts (ohne Power-Symbole, DNP, not-in-BOM)."""
    tree = parse_sexpr(path.read_text(encoding="utf-8", errors="replace"))
    root = first(tree, "kicad_sch")
    if root is None:
        return []
    out = []
    for sym in children(root, "symbol"):
        lib = first(sym, "lib_id")
        if not lib or len(lib) < 2:
            continue
        lib_id = lib[1]
        if lib_id.startswith("power:") or "PWR_FLAG" in lib_id:
            continue
        if flag(sym, "dnp") or (first(sym, "in_bom") and not flag(sym, "in_bom")):
            continue
        props = {p[1]: p[2] for p in children(sym, "property") if len(p) > 2}
        # Referenzen aus den Instanzdaten (stimmen auch bei mehrfach verwendeten Blättern)
        refs = []
        inst = first(sym, "instances")
        if inst:
            for proj in children(inst, "project"):
                for p in children(proj, "path"):
                    r = first(p, "reference")
                    if r and len(r) > 1:
                        refs.append(r[1])
        if not refs:
            refs = [props.get("Reference", "?")]
        refs = [r for r in refs if not r.startswith("#")]
        if not refs:
            continue
        out.append({
            "lib_id": lib_id,
            "value": props.get("Value", "").strip(),
            "footprint": props.get("Footprint", "").split(":")[-1].strip(),
            "mf": next((props[k] for k in MF_KEYS if props.get(k, "").strip()), "").strip(),
            "mpn": next((props[k] for k in MPN_KEYS if props.get(k, "").strip()), "").strip(),
            "refs": refs,
        })
    return out


# ── Schaltpläne finden und zu Platinen gruppieren ────────────────────────────

def find_schematics(folder):
    found = []
    for dirpath, dirnames, filenames in os.walk(folder):
        dirnames[:] = [d for d in dirnames
                       if d not in SKIP_DIRS and not d.startswith("_") and not d.endswith("-backups")]
        for f in filenames:
            if f.endswith(".kicad_sch") and not f.startswith(("_autosave", "~", "#")):
                found.append(Path(dirpath) / f)
    return sorted(found)


def group_boards(schematics):
    """Eine Platine = alle Schaltpläne im Ordner einer .kicad_pro (hierarchische Blätter)."""
    boards = defaultdict(list)
    for s in schematics:
        pros = sorted(s.parent.glob("*.kicad_pro"))
        name = pros[0].stem if pros else s.stem
        boards[(s.parent, name)].append(s)
    return boards


# Referenz-Präfix → Typ; zuverlässiger als Bibliotheksnamen (Klemmen heissen oft "24V_Input")
REF_TYPES = {"J": "Steckverbinder", "P": "Steckverbinder", "X": "Steckverbinder",
             "CN": "Steckverbinder", "TP": "Testpunkt", "H": "Mechanik", "MH": "Mechanik",
             "SW": "Schalter", "S": "Schalter", "F": "Sicherung", "FB": "Induktivität",
             "SJ": "Lötbrücke", "JP": "Lötbrücke",
             "R": "Widerstand", "RN": "Widerstand", "C": "Kondensator", "L": "Induktivität"}
# nur wenn die Bibliothek nichts hergibt (z.B. aus Eagle importierte Projekte)
REF_FALLBACK = {"D": "Diode", "LED": "LED", "Q": "Transistor", "T": "Transistor",
                "Y": "Quarz", "U": "IC", "IC": "IC", "K": "Relais"}


def kind(lib_id, value, ref=""):
    prefix = re.match(r"[A-Za-z]*", ref).group(0).upper()
    if prefix in REF_TYPES:
        return REF_TYPES[prefix]
    hay = f"{lib_id} {value}".lower()
    for key, t in TYPE_MAP:
        if key.lower() in hay:
            return t
    return REF_FALLBACK.get(prefix, "Sonstiges")


def natural(ref):
    m = re.match(r"([A-Za-z_#]*)(\d*)", ref)
    return (m.group(1), int(m.group(2)) if m.group(2) else 0, ref)


def bom_for(files, warn):
    groups = {}
    for f in files:
        try:
            syms = symbols_of(f)
        except (ValueError, OSError) as e:
            warn(f"übersprungen (nicht lesbar): {f} – {e}")
            continue
        for s in syms:
            key = (s["value"], s["footprint"], s["lib_id"])
            g = groups.setdefault(key, {**s, "refs": set()})
            g["refs"].update(s["refs"])
            g["mf"] = g["mf"] or s["mf"]
            g["mpn"] = g["mpn"] or s["mpn"]
    rows = []
    for g in groups.values():
        if not g["value"]:
            continue
        g["typ"] = kind(g["lib_id"], g["value"], min(g["refs"], key=natural))
        g["refs"] = sorted(g["refs"], key=natural)
        rows.append(g)
    rows.sort(key=lambda r: natural(r["refs"][0]))
    return rows


# ── Markdown ─────────────────────────────────────────────────────────────────

def cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def part_name(row):
    """Name der Bauteil-Notiz, oder None bei generischen Werten (10k, 100n …)."""
    if row["typ"] in GENERIC_TYPES or row["lib_id"].startswith(("Connector", "Mechanical")):
        return None
    name = re.sub(r'[\[\]#|^\\/:*?"<>]', "-", row["value"]).strip(" -")
    return name or None


def label(row):
    n = part_name(row)
    return f"[[{n}]]" if n else cell(row["value"])


def bom_section(boards_rows, ordner, warn_lines):
    lines = [START, f"*Automatisch aus den KiCad-Schaltplänen in `{ordner}` – nicht von Hand ändern "
             "(wird bei `notizen-bom` überschrieben). Bauteil-Wissen gehört in die verlinkte Bauteil-Notiz.*", ""]
    multi = len(boards_rows) > 1
    for name, rows in boards_rows:
        if multi:
            lines += [f"### {name}", ""]
        if not rows:
            lines += ["(keine Bauteile gefunden)", ""]
            continue
        lines += ["| Anz. | Bauteil | Typ | Footprint | Referenzen |", "|---|---|---|---|---|"]
        for r in rows:
            lines.append(f"| {len(r['refs'])} | {label(r)} | {r['typ']} | {cell(r['footprint'])} "
                         f"| {cell(', '.join(r['refs']))} |")
        lines.append("")
    lines += warn_lines
    lines.append(END)
    return "\n".join(lines)


def put_section(note_text, section):
    """Abschnitt zwischen den Markern ersetzen oder vor '## Verlauf' einfügen."""
    if START in note_text and END in note_text:
        a = note_text.index(START)
        b = note_text.index(END) + len(END)
        return note_text[:a] + section + note_text[b:], "ersetzt"
    if START in note_text or END in note_text:
        raise ValueError("nur einer der beiden notizen-bom-Marker vorhanden – bitte von Hand reparieren")
    if re.search(rf"^{re.escape(HEADING)}\s*$", note_text, re.M):
        raise ValueError(f"'{HEADING}' existiert ohne Marker – wird nicht angefasst")
    block = f"{HEADING}\n{section}\n\n"
    m = re.search(r"^## Verlauf\s*$", note_text, re.M)
    if m:
        return note_text[:m.start()] + block + note_text[m.start():], "eingefügt"
    return note_text.rstrip("\n") + "\n\n" + block.rstrip("\n") + "\n", "angehängt"


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def library(usage):
    named = defaultdict(lambda: {"typ": "", "mf": "", "mpn": "", "fps": set(), "projekte": set()})
    generic = defaultdict(lambda: {"projekte": set()})
    for projekt, rows in usage.items():
        for r in rows:
            n = part_name(r)
            if n:
                e = named[n]
                e["typ"] = e["typ"] or r["typ"]
                e["mf"] = e["mf"] or r["mf"]
                e["mpn"] = e["mpn"] or r["mpn"]
                if r["footprint"]:
                    e["fps"].add(r["footprint"])
                e["projekte"].add(projekt)
            else:
                generic[(r["typ"], r["value"], r["footprint"])]["projekte"].add(projekt)

    def links(ps):
        return ", ".join(f"[[{p}]]" for p in sorted(ps))

    lines = ["# Bauteile", "",
             "*Automatisch erzeugt von `notizen-bom` aus allen Projekt-Schaltplänen – nicht von Hand ändern. "
             "Eigenes Wissen zu einem Bauteil: auf den Bauteil-Link klicken, Obsidian legt die Notiz an "
             "(am besten in `Wissen/`).*", "",
             f"## Bauteile ({len(named)})", "",
             "| Bauteil | Typ | Hersteller / Bestellnr. | Footprint | Verwendet in |", "|---|---|---|---|---|"]
    for n in sorted(named, key=str.lower):
        e = named[n]
        bezug = " / ".join(x for x in (e["mf"], e["mpn"]) if x)
        lines.append(f"| [[{n}]] | {e['typ']} | {cell(bezug)} | {cell(', '.join(sorted(e['fps'])))} "
                     f"| {links(e['projekte'])} |")
    lines += ["", f"## Passive Bauteile und Steckverbinder ({len(generic)})", "",
              "| Typ | Wert | Footprint | Verwendet in |", "|---|---|---|---|"]
    for (typ, val, fp) in sorted(generic, key=lambda k: (k[0], k[1].lower(), k[2])):
        lines.append(f"| {typ} | {cell(val)} | {cell(fp)} | {links(generic[(typ, val, fp)]['projekte'])} |")
    return "\n".join(lines) + "\n"


def write_if_changed(path, text, dry, log):
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if old == text:
        return False
    if dry:
        log(f"würde schreiben: {path}")
    else:
        tmp = path.with_name(f".{path.name}.notizen-bom.tmp")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, path)
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--notizen", default=os.environ.get("NOTIZEN", str(Path.home() / "Notizen")))
    ap.add_argument("--dry-run", action="store_true", help="nichts schreiben, nur anzeigen")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    root = Path(args.notizen).expanduser()
    if not (root / "Projekte").is_dir():
        sys.exit(f"notizen-bom: {root}/Projekte nicht gefunden")

    def log(msg):
        print(f"notizen-bom: {msg}")

    usage, changed, problems = {}, 0, 0
    for note in sorted((root / "Projekte").glob("*/*.md")):
        text = note.read_text(encoding="utf-8")
        ordner = frontmatter(text).get("ordner", "")
        if not ordner:
            continue
        folder = Path(os.path.expanduser(ordner))
        if not folder.is_dir():
            if args.verbose:
                log(f"{note.stem}: Ordner fehlt ({ordner}) – übersprungen")
            continue
        boards = group_boards(find_schematics(folder))
        if not boards:
            continue
        warns = []
        boards_rows = []
        for (_, name), files in sorted(boards.items(), key=lambda kv: kv[0][1].lower()):
            boards_rows.append((name, bom_for(files, lambda w: warns.append(f"*{w}*"))))
        usage[note.stem] = [r for _, rows in boards_rows for r in rows]
        if not usage[note.stem] and START not in text:
            if args.verbose:
                log(f"{note.stem}: Schaltpläne ohne Bauteile (leere Vorlage?) – übersprungen")
            continue
        try:
            new, how = put_section(text, bom_section(boards_rows, ordner, warns))
        except ValueError as e:
            log(f"{note.stem}: {e}")
            problems += 1
            continue
        if write_if_changed(note, new, args.dry_run, log):
            changed += 1
            log(f"{note.stem}: Stückliste {how} ({sum(len(r) for _, r in boards_rows)} Positionen)")
        elif args.verbose:
            log(f"{note.stem}: unverändert")

    lib = root / "Wissen" / "Bauteile.md"
    lib.parent.mkdir(exist_ok=True)
    if write_if_changed(lib, library(usage), args.dry_run, log):
        changed += 1
        log(f"Wissen/Bauteile.md aktualisiert ({sum(1 for u in usage.values() if u)} Projekte)")
    log(f"fertig: {changed} Datei(en) {'zu ändern' if args.dry_run else 'geändert'}, {problems} Problem(e)")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
