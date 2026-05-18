# CI / GitHub Actions

Overview of the automated workflows in `.github/workflows/` and what each does.

## TL;DR table

| Workflow | When | What | Output |
|---|---|---|---|
| `build.yml` | PR + push to main | Build both hosts (`meo` + `meo-work`) | PR check status (green/red) |
| `check.yml` | Every push | `nix flake check --no-build` (eval only) | PR check status |
| `lint.yml` | PR + push to main | alejandra + statix + deadnix | Warnings (non-blocking) |
| `flake-update.yml` | Monday 04:00 UTC | `nix flake update` + open PR | PR with diff |
| `track-zaneyos.yml` | Monday 06:00 UTC | Compare upstream zaneyos commits | GitHub Issue |
| `hyprland-tracker.yml` | Daily 12:00 UTC | Check Hyprland releases | GitHub Issue if new |
| `vulnix.yml` | Tuesday 08:00 UTC | CVE scan of meo's closure | Artifact + Issue if HIGH |
| `automerge.yml` | PR labeled `automerge` | Enable GitHub auto-merge | (opt-in via label) |

Plus `.github/dependabot.yml` — weekly PRs to keep workflow `uses:` versions current.

## How it all fits together

```
┌─────────────────────────────────────────────────────────────────┐
│ Monday 04:00 UTC                                                │
│ flake-update.yml runs `nix flake update` → opens PR             │
│                                                                 │
│           │                                                     │
│           ▼                                                     │
│ build.yml fires on the PR → builds meo + meo-work               │
│ check.yml fires on the PR → flake check                         │
│ lint.yml fires on the PR → format/anti-patterns                 │
│                                                                 │
│           │                                                     │
│           ▼                                                     │
│ You wake up Monday morning to a PR. Status checks visible.      │
│   - All green → squash-merge → fr on both hosts → done          │
│   - Red → click into failing check, see what broke              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Monday 06:00 UTC                                                │
│ track-zaneyos.yml opens a digest issue if upstream has activity │
│                                                                 │
│ Daily 12:00 UTC                                                 │
│ hyprland-tracker.yml opens issue if hyprwm released new tag     │
│                                                                 │
│ Tuesday 08:00 UTC                                               │
│ vulnix.yml opens issue if HIGH-severity CVE in meo's closure    │
└─────────────────────────────────────────────────────────────────┘
```

## Setup checklist (one-time, on GitHub)

These workflows are functional out-of-the-box BUT you should adjust a few GitHub repo settings for max effectiveness:

### 1. Allow Actions to write to PRs (already enabled by default for public repos)
Settings → Actions → General → "Workflow permissions"
- ✅ "Read and write permissions"
- ✅ "Allow GitHub Actions to create and approve pull requests"

(Without this, `flake-update.yml` can't open PRs.)

### 2. Branch protection on `main` (recommended for safety with trading bot)
Settings → Branches → Add rule for `main`:
- ✅ "Require status checks to pass before merging"
  - Add: `Build meo`, `Build meo-work`, `nix flake check (eval)`
- ✅ "Do not allow bypassing the above settings"

This prevents broken PRs from being merged even if you click "Merge" by accident. The auto-sync `_zsync` from `fr` pushes DIRECTLY to main, bypassing PRs — so this only protects against the PR flow (flake-update, manual edits via PR).

### 3. (Optional) Enable auto-merge globally for repo
Settings → General → Pull Requests:
- ✅ "Allow auto-merge"

This unlocks `automerge.yml`. With branch protection + auto-merge enabled, you can:
- Add `automerge` label to a PR
- GitHub merges it automatically once all required status checks pass
- You never touch the merge button

### 4. (Optional) Configure required labels for `automerge`
If you want `flake-update.yml` PRs to auto-merge:
- Edit `flake-update.yml` and add `automerge` to `pr-labels:`
- Trust the build CI to catch breakage
- Risk: a breaking change that builds but fails at runtime will hit your system

For trading-bot safety, **don't enable auto-merge automatically.** Manual click is 10 seconds.

## What about Garnix.io?

Garnix is already in our substituter list (`modules/upstream/core/cachix.nix`). It serves cached builds for affinity-nix's wine derivations. Our CI uses Garnix as a binary cache — that's why `build.yml` finishes in minutes instead of hours.

If you want to **publish** to Garnix (let Garnix serve your custom builds to others), add `garnix-io/garnix-action@v1` to `build.yml`. Not needed for personal use.

## Cost (free tier)

- Public repos: **unlimited GitHub Actions minutes** ✓
- Private repos: 2000 min/month free
- Our usage estimate: <300 min/month (mostly cached builds)

We're not getting close to limits.

## Disabling a workflow temporarily

```bash
# Disable
gh workflow disable "Build NixOS hosts"

# Re-enable
gh workflow enable "Build NixOS hosts"

# Manually trigger
gh workflow run "Update flake inputs"
```

Or edit the workflow file and change `on:` to remove triggers.

## When something goes wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `flake-update.yml` PR doesn't appear | Workflow permissions missing | Settings → Actions → "Read and write permissions" |
| `build.yml` hangs on Wine compile | Garnix cache miss for affinity-nix | Usually transient — re-run, or wait until garnix CI catches up |
| `track-zaneyos.yml` digest empty | Upstream had nothing new in `modules/` | Working as intended |
| `hyprland-tracker.yml` duplicate issues | Old issue closed too quickly | Re-open or re-label with `hyprland-release` |
| `vulnix.yml` always opens issue | Real CVEs (yay), or false positives | Triage per `vulnix-report.txt` |
| `automerge.yml` doesn't merge | Branch protection not configured, or required checks failing | Setup checklist above |
