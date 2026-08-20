# Automations-Wächter — Design-Spec

**Datum:** 2026-08-20
**Host(s):** meo, meo-work
**Status:** Entwurf zur Review

## 1. Problem & Kontext

Die Update-Automation dieses Systems ist bereits vollständig gebaut
(`.github/workflows/{flake-update,build,automerge,vulnix}.yml` + die
zsh-Funktionen `fr`/`fu`/`_zpush` in
`modules/upstream/home/zsh/default.nix`). Sie **erzeugt** wöchentlich
frische `flake.lock`-PRs, scheitert aber **still am letzten Merge-/
Aktivierungs-Schritt**: der CI-Branch `update_flake_lock_action` trug am
2026-08-17 bereits ein frisches nixpkgs (2026-08-16), während `main`
seit 2026-07-15 stillstand — weil `automerge.yml` ohne scharfe
branch-protection-Checks ins Leere läuft und niemand es bemerkt.

**Kernproblem:** Es fehlt kein weiteres Automatisieren, sondern ein
**Wächter, der merkt wenn eine bestehende Automation still versagt** —
und der bei Config-relevanten Problemen einen konkreten Fix vorschlägt.

## 2. Ziele / Nicht-Ziele

**Ziele**
- Alle paar Tage den Gesundheitszustand der System-Automationen prüfen.
- Bei Problemen: Desktop-Notification (Noctalia) + strukturierter Report.
- Bei Config-lösbaren Problemen: automatisch ein **Fix-PR** (nicht
  gemergt, nicht live aktiviert) mit Diagnose + Vorschlag.
- Reproduzierbar: Prüf-Logik versioniert in der Nix-Config.

**Nicht-Ziele (bewusst)**
- Kein automatisches `nixos-rebuild switch`/`boot` auf dem laufenden
  System (Freeze-Regressions-Risiko, NVIDIA-Recompile).
- Kein automatisches Mergen von PRs.
- Kein Anfassen der bewussten Hardware-Freeze-Workarounds
  (i915-PSR, RTD3, dpcd-backlight, Docker liveRestore, CIFS soft-mount,
  zram+Swapfile, Ladelimit 80 %).
- `system.autoUpgrade` bleibt bewusst ungenutzt.

## 3. Architektur — zwei Schichten

### Schicht 1 — Sensor (deterministisch, in Nix)

Neues Home-Manager-Modul `modules/meo/automation-health.nix`, importiert
in `modules/meo/default.nix`, auf **beiden** Hosts aktiv (via `fr`-Sync
konsistent gehalten).

- **systemd-user-Service** `automation-health-check` (Type=oneshot),
  ausgeführt von **systemd-user-Timer** `OnCalendar` alle 3 Tage,
  `Persistent = true` (holt verpasste Läufe nach Standby/Aus nach),
  `RandomizedDelaySec`.
- Ein `writeShellApplication`-Skript (deps: git, gh, jq, coreutils,
  systemd, libnotify) führt eine Reihe von **Checks** aus und schreibt
  einen strukturierten Report nach
  `~/.local/state/automation-health/report.json` + Menschen-lesbar
  `report.txt`.
- Bei Status `warn`/`fail` in mind. einem Check: **`notify-send`**
  (Dringlichkeit nach Schweregrad) mit Kurzfassung.

**Checks (v1):**

| ID | Prüft | fail-Bedingung (Beispiel) |
|----|-------|---------------------------|
| `update-loop` | Hängt der Merge-Loop? | `origin/main` seit >10 d unbewegt UND `origin/update_flake_lock_action` neuer |
| `ci-build` | Letzter `build.yml`-Run auf `main` | Status ≠ success (`gh run list`) |
| `lock-age` | Alter des nixpkgs-Node in `flake.lock` | > 21 d |
| `open-prs` | Stapeln sich Update/Dependabot-PRs? | offene PRs mit Label `automerge`/`dependencies` > 3 |
| `failed-units` | `systemctl --user`/`--system --failed` | > 0 failed units |
| `gc-timer` | `nh-clean.timer` aktiv & lief kürzlich | Timer inaktiv oder LastTrigger > 14 d |
| `backup` | (sobald Restic existiert) letzter Snapshot | > 48 h alt / Timer failed |

Checks sind **datengetrieben** (Liste im Skript), leicht erweiterbar.
Netzwerk-Checks (`gh`, `git ls-remote`) sind best-effort: bei fehlendem
Netz → Status `skip`, kein Fehlalarm.

**Report-Schema (`report.json`):**
```json
{
  "generated": "<ISO-8601, vom Skript gestempelt>",
  "host": "meo",
  "overall": "ok|warn|fail",
  "checks": [
    {"id": "update-loop", "status": "fail", "detail": "main 36d alt, update-branch neuer", "hint": "branch protection prüfen / PR mergen"}
  ]
}
```

### Schicht 2 — Gehirn (agentische Cloud-Routine)

Eine per `/schedule` angelegte **Cron-Routine** (Claude Code), Cadence
alle 3 Tage, versetzt zum Sensor. Die Routine-Definition wird als
`automations/watcher-routine.md` ins Repo committet (Versionierung), der
Zeitplan selbst lebt in Claude Code.

**Ablauf der Routine:**
1. Repo `nixos-config` auschecken, `report.json` beider Hosts lesen
   (bzw. selbst die Checks nachfahren, falls kein frischer Report da).
2. Ist `overall == ok` → nichts tun, still beenden.
3. Sonst pro `fail`/`warn`-Check: Ursache diagnostizieren
   (Reasoning über Repo, CI-Logs, git-Historie).
4. Für **config-lösbare** Probleme: Branch `watcher/fix-<id>-<datum>`
   anlegen, minimalen Fix committen, **PR** aufmachen mit: was war
   kaputt, warum, was der Fix tut, wie verifiziert wurde.
5. Für **nicht-config-lösbare** Probleme (z.B. „branch protection in
   GitHub-Settings aktivieren", „PR X manuell mergen"): kein Code-PR,
   sondern ein **GitHub-Issue** / Kommentar mit klarer Handlungsanweisung.

**Guardrails der Routine (Teil der committeten Definition):**
- Niemals `nixos-rebuild switch`/`boot`, nie live aktivieren.
- Niemals PRs selbst mergen.
- Freeze-Workarounds (Liste oben) nie ändern/entfernen.
- Vor jedem Fix-PR: `nix build .#nixosConfigurations.{meo,meo-work}
  .config.system.build.toplevel --dry-run` als Gate (CLAUDE.md-Regel:
  nie ohne Dry-Build beider Hosts).
- Ein PR pro Problem, klein und fokussiert; keine unrelated Refactors.

## 4. Datenfluss

```
systemd-user-Timer (3d, Persistent)
  → automation-health-check (Sensor, Nix)
      → report.json + report.txt  (~/.local/state/automation-health/)
      → notify-send bei warn/fail
Cloud-Routine (3d, versetzt)
  → liest report.json (+ Repo/CI)
      → ok?  → Ende
      → sonst → Fix-PR (config) oder Issue (manuell)
                → Mensch reviewt/merged → `fr` zieht Fix
```

## 5. Fehlerbehandlung

- Sensor-Skript: `set -euo pipefail`; jeder Check gekapselt, ein
  fehlschlagender Check (z.B. `gh` nicht auth) → `status: skip` mit
  Grund, bricht den Gesamtlauf nicht ab.
- Kein Netz → Netz-Checks `skip`, lokale Checks laufen weiter.
- Routine: findet sie keinen frischen Report → fährt Checks selbst
  nach; kann sie nichts sicher fixen → Issue statt PR (nie raten).

## 6. Testing

- Sensor: Skript lokal mit `--dry-run`/Env-Overrides gegen
  konstruierte Zustände testen (z.B. `MAIN_AGE_DAYS=40` injizieren) →
  erwartete `status`-Werte prüfen. Report-JSON gegen Schema validieren.
- Verifizieren, dass ein künstlicher `fail` tatsächlich eine
  Notification auslöst.
- Routine: erster Lauf manuell angestoßen und beobachtet, ob bei einem
  echten offenen `update_flake_lock_action` ein sinnvoller PR/Issue
  entsteht.
- Nach Nix-Änderung: Dry-Build beider Hosts (Pflicht vor Push).

## 7. Reproduzierbarkeit

- Sensor vollständig in Nix → auf frischem System automatisch da.
- Routine-Zeitplan lebt in Claude Code (nicht in Nix), aber Definition
  als `automations/watcher-routine.md` versioniert → nachbaubar.
- Keine neuen Secrets nötig (nutzt vorhandene `gh`-Auth des Users).

## 8. Offene Punkte

- Genaue Schwellen (`lock-age > 21 d`, `main > 10 d`) nach erstem
  Realbetrieb justieren.
- `backup`-Check erst aktiv, sobald Restic (separates Vorhaben) existiert.
- Optional später: Sensor-Report in Noctalia-Widget statt nur Toast.
