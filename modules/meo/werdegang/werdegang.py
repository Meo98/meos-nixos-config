"""Werdegang: nach einer Claude-Code-Sitzung festhalten, was an welchem Projekt passiert ist.

Aufruf: werdegang <transcript.jsonl> <session_id>
Läuft im Hintergrund, gestartet vom SessionEnd-Hook (werdegang-hook).

1. Liest die Projektnotizen in ~/Notizen/Projekte (Frontmatter `ordner:`).
2. Sucht im Sitzungsprotokoll die Dateien, die Claude geändert hat (Edit/Write/NotebookEdit).
   Liegt keine davon in einem Projektordner, ist nichts zu tun (kein Claude-Aufruf).
3. Baut eine gekürzte Zusammenfassung der Sitzung (Fragen, Antworten, Werkzeuge, Commits)
   und lässt `claude -p` daraus je Projekt einen Eintrag in <Projekt>-Werdegang.md schreiben.

Wird eine Sitzung fortgesetzt (--resume), feuert SessionEnd erneut; der Zustand pro
Sitzung merkt sich, bis zu welcher Zeile schon verarbeitet wurde.
"""

import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
NOTIZEN = HOME / "Notizen"
PROJEKTE = NOTIZEN / "Projekte"
ZUSTAND = Path(os.environ.get("WERDEGANG_ZUSTAND", HOME / ".local/state/werdegang"))

# Ordner, die zu allgemein sind, um daraus ein Projekt abzuleiten
ZU_ALLGEMEIN = {HOME, HOME / "Downloads", HOME / "Dokumente", NOTIZEN}

MAX_ZEICHEN = 60_000  # Obergrenze für die Zusammenfassung an Claude

# Lange Zufallsfolgen (API-Schlüssel, Tokens, Hashes) nie weitergeben.
# Commit-Hashes bleiben, die stehen nur im Git-Teil und sind kürzer gekürzt.
GEHEIM = re.compile(r"\b(?=[A-Za-z0-9_\-+/]*\d)(?=[A-Za-z0-9_\-+/]*[A-Za-z])[A-Za-z0-9_\-+/]{24,}={0,2}")
PRIVAT = re.compile(r"Persönlich/")


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    if not m:
        return {}
    werte = {}
    for zeile in m.group(1).splitlines():
        k = re.match(r"(\w+):\s*(.*)$", zeile)
        if k:
            werte[k.group(1)] = k.group(2).strip()
    return werte


def projekte():
    """Projektnotizen mit Status und einem brauchbaren Ordner."""
    liste = []
    for notiz in PROJEKTE.rglob("*.md"):
        if notiz.stem.endswith("-Werdegang"):
            continue
        fm = frontmatter(notiz.read_text(encoding="utf-8", errors="replace"))
        if not fm.get("status") or not fm.get("ordner"):
            continue
        ordner = Path(os.path.expanduser(fm["ordner"])).resolve()
        if ordner in ZU_ALLGEMEIN or not ordner.is_dir():
            continue
        liste.append({"notiz": notiz, "ordner": ordner, "repo": fm.get("repo", "")})
    return liste


def kuerzen(text, n):
    text = GEHEIM.sub("[entfernt]", text.strip())
    return text if len(text) <= n else text[:n] + " …"


def bloecke(nachricht):
    inhalt = (nachricht or {}).get("content")
    if isinstance(inhalt, str):
        return [{"type": "text", "text": inhalt}]
    return inhalt if isinstance(inhalt, list) else []


def lesen(transcript, ab_zeile):
    """Geänderte Dateien, Zeitraum und eine gekürzte Erzählung der Sitzung ab ab_zeile."""
    geaendert, erzaehlung = set(), []
    beginn = ende = None
    zeilen = 0
    with open(transcript, encoding="utf-8", errors="replace") as f:
        for zeilen, roh in enumerate(f, 1):
            if zeilen <= ab_zeile:
                continue
            try:
                d = json.loads(roh)
            except json.JSONDecodeError:
                continue
            art = d.get("type")
            if art not in ("user", "assistant") or d.get("isSidechain"):
                continue
            zeit = d.get("timestamp")
            if zeit:
                beginn = beginn or zeit
                ende = zeit
            for b in bloecke(d.get("message")):
                typ = b.get("type")
                if art == "user" and typ == "text":
                    t = b.get("text", "")
                    # Systemhinweise und eingeblendete Befehle sind kein Gespräch
                    if t.startswith("<") or "system-reminder" in t[:200]:
                        continue
                    erzaehlung.append("USER: " + kuerzen(t, 600))
                elif art == "assistant" and typ == "text":
                    erzaehlung.append("CLAUDE: " + kuerzen(b.get("text", ""), 900))
                elif art == "assistant" and typ == "tool_use":
                    name, ein = b.get("name", ""), b.get("input") or {}
                    pfad = ein.get("file_path") or ein.get("notebook_path")
                    if name in ("Edit", "Write", "NotebookEdit", "MultiEdit") and pfad:
                        geaendert.add(Path(pfad).resolve())
                        erzaehlung.append(f"  [{name} {pfad}]")
                    elif name == "Bash":
                        beschr = ein.get("description") or ein.get("command", "")
                        erzaehlung.append("  [Bash: " + kuerzen(beschr, 160) + "]")
    return geaendert, erzaehlung, beginn, ende, zeilen


def git_log(ordner, beginn, ende):
    if not (ordner / ".git").exists() or not beginn:
        return ""
    try:
        aus = subprocess.run(
            ["git", "-C", str(ordner), "log", "--all", "--no-merges", "--format=%h %ad %s",
             "--date=format:%Y-%m-%d %H:%M", f"--since={beginn}", f"--until={ende}"],
            capture_output=True, text=True, timeout=30,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ""
    # Auto-Sync-Commits von `fr` sagen nichts über den Inhalt
    return "\n".join(z for z in aus.splitlines() if "chore: sync from" not in z)


def main():
    transcript, sitzung = sys.argv[1], sys.argv[2]
    # Claude schreibt das Protokoll asynchron; beim SessionEnd fehlen evtl. die letzten Zeilen
    if not os.environ.get("WERDEGANG_TROCKEN"):
        time.sleep(10)
    ZUSTAND.mkdir(parents=True, exist_ok=True)
    zustand = ZUSTAND / f"{sitzung}.json"
    ab = json.loads(zustand.read_text())["zeile"] if zustand.exists() else 0

    geaendert, erzaehlung, beginn, ende, zeilen = lesen(transcript, ab)
    zustand.write_text(json.dumps({"zeile": zeilen, "transcript": transcript}))

    # Projekt ↔ geänderte Dateien; Dateien in Persönlich/ zählen nie
    treffer = {}
    for p in projekte():
        dateien = sorted(str(d) for d in geaendert if d.is_relative_to(p["ordner"]) and not PRIVAT.search(str(d)))
        if dateien:
            treffer[p["notiz"]] = (p, dateien)
    if not treffer:
        print(f"{datetime.now():%F %T} {sitzung}: kein Projekt betroffen")
        return

    teile = []
    for notiz, (p, dateien) in treffer.items():
        rel = notiz.relative_to(NOTIZEN)
        teile.append(
            f"### Projekt: {rel} (Ordner {p['ordner']}, Repo {p['repo'] or '–'})\n"
            f"Werdegang-Datei: {rel.with_name(rel.stem + '-Werdegang.md')}\n"
            "Geänderte Dateien:\n" + "\n".join("- " + d for d in dateien[:40]) +
            ("\nCommits in dieser Zeit:\n" + log if (log := git_log(p["ordner"], beginn, ende)) else "")
        )
    text = "\n".join(erzaehlung)
    if len(text) > MAX_ZEICHEN:
        # Anfang (Absicht) und Ende (Ergebnis) sind am wichtigsten
        text = text[: MAX_ZEICHEN // 3] + "\n[… Mitte gekürzt …]\n" + text[-2 * MAX_ZEICHEN // 3 :]

    eingabe = (
        f"Sitzung {sitzung}, {beginn} bis {ende}.\n\n" + "\n\n".join(teile) +
        "\n\n## Gesprächsverlauf (gekürzt)\n" + text
    )
    if os.environ.get("WERDEGANG_TROCKEN"):
        # Probelauf: nur zeigen, was Claude bekäme
        print(eingabe)
        return
    prompt = os.environ["WERDEGANG_PROMPT"]
    env = dict(os.environ, CLAUDE_WERDEGANG="1")  # der Hook erkennt daran sich selbst
    lauf = subprocess.run(
        ["claude", "-p", prompt, "--model", "sonnet", "--permission-mode", "acceptEdits",
         "--no-session-persistence", "--allowedTools", "Read", "Write", "Edit", "Glob"],
        input=eingabe, text=True, cwd=NOTIZEN, env=env, capture_output=True, timeout=900,
    )
    print(f"{datetime.now():%F %T} {sitzung}: {', '.join(n.stem for n in treffer)} → Exit {lauf.returncode}")
    if lauf.returncode:
        print(lauf.stderr[-2000:])


if __name__ == "__main__":
    main()
