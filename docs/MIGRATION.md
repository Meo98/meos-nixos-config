# Migration to Option C-clean

**Date:** 2026-05-18
**From:** ZaneyOS fork (`my-zaneyos-config`, 123 ahead / 61 behind upstream)
**To:** Standalone "MeoNix" configuration (`nixos-config`)
**Strategy:** Honest Clean Fork — physical separation of custom (`modules/meo/`) vs vendored upstream (`modules/upstream/`)

## Why this approach

Three alternatives were considered:

| Option | Approach | Rejected because |
|---|---|---|
| **A — Augmented Input** | zaneyos as flake input + Nix derivation overlay to inject our `hosts/` | Hacky derivation magic, breaks subtly if upstream changes structure |
| **B — Patched Fork** | Maintain a private fork of zaneyos on GitHub with path-coupling patches | Makes you Maintainer of patch-set forever |
| **C — Clean Fork** ⭐ | Physical separation in our repo: `modules/upstream/` (frozen snapshot) + `modules/meo/` (custom) | Chosen — pragmatic, low-risk, no magic |

**The fundamental blocker for Options A & B:** zaneyos has 34+ modules that do `import ../../../hosts/${host}/variables.nix` as **file-relative** imports. They would not work from `/nix/store/...zaneyos-input/` because our `hosts/meo/` lives in our repo, not in the zaneyos input tree. Working around this requires either Nix derivation magic (Option A) or patching every coupled module (Option B).

## Goals

- ✅ Sever upstream git relationship — `git remote remove upstream`
- ✅ Repo identity: "MeoNix" — not "ZaneyOS Unstable"
- ✅ Clean physical separation: `modules/meo/` (yours) vs `modules/upstream/` (vendored)
- ✅ Local path rename: `~/zaneyos` → `~/nixos-config`
- ✅ Documentation: README.md (humans), CLAUDE.md (AI assistants), docs/* (architecture)
- ✅ Cleanup: delete unused hosts/profiles/scripts from upstream
- ✅ Both hosts (`meo` + `meo-work`) keep working

## What gets reorganized

### Custom modules → `modules/meo/`

These are modules that ONLY exist in our fork (not in upstream zaneyos):

| Current path | New path |
|---|---|
| `modules/core/bambu.nix` | `modules/meo/bambu.nix` |
| `modules/home/hyprland/vol-smart.nix` | `modules/meo/hyprland/vol-smart.nix` |
| `modules/home/hyprland/bright-smart.nix` | `modules/meo/hyprland/bright-smart.nix` |
| `modules/home/hyprland/pyprland.nix` | `modules/meo/hyprland/pyprland.nix` |
| `modules/home/scripts/bt-audio-monitor.nix` | `modules/meo/scripts/bt-audio-monitor.nix` |
| `modules/home/scripts/bt-audio-switch.nix` | `modules/meo/scripts/bt-audio-switch.nix` |
| `modules/home/scripts/setup-secrets.nix` | `modules/meo/scripts/setup-secrets.nix` |
| `modules/home/scripts/travel-mode.nix` | `modules/meo/scripts/travel-mode.nix` |
| `modules/home/trading-bot.nix` | `modules/meo/trading-bot.nix` |

### Vendored upstream → `modules/upstream/`

Everything else in `modules/` moves to `modules/upstream/`:
- `modules/core/` (minus `bambu.nix`) → `modules/upstream/core/`
- `modules/drivers/` → `modules/upstream/drivers/`
- `modules/home/` (minus custom files above) → `modules/upstream/home/`
- `modules/src/` → `modules/upstream/src/`

Modifications we've made to upstream files remain in those files; they are marked with `# MODIFIED` comments where relevant. The directory name "upstream" reflects origin, not "pristine — never touched".

### Profile reorganization

`profiles/` is zaneyos-infrastructure, also moves:
- `profiles/nvidia-laptop/` → `modules/upstream/profiles/nvidia-laptop/`
- `profiles/intel/` → `modules/upstream/profiles/intel/`

### Deletions (dead weight)

| Path | Why |
|---|---|
| `install-zaneyos.sh` | Upstream installer, never used |
| `FAQ.md`, `FAQ.es.md` | Upstream docs (130KB) |
| `CHANGELOG.md` | Upstream's changelog |
| `README.es.md` | Spanish version of upstream README |
| `CONTRIBUTING.md` | Upstream contribution guide |
| `CODE_OF_CONDUCT.md` | Upstream community policy |
| `WARP.md`, `.warp.md` | WSL/WARP docs |
| `zcli.md`, `zcli.es.md` | zaneyos CLI docs (we use `nh` instead) |
| `LICENSE.md` | Upstream MIT (we keep similar but rewrite for our names) |
| `hosts/default/` | zaneyos template host |
| `hosts/zaneyos-24-vm/` | zaneyos template host |
| `hosts/zaneyos-oem/` | zaneyos template host |
| `profiles/amd/`, `profiles/nvidia/`, `profiles/amd-hybrid/`, `profiles/amd-nvidia-hybrid/`, `profiles/vm/` | Unused profiles (we only use nvidia-laptop + intel) |
| `img/` | Upstream screenshots |
| `cheatsheets/` | Upstream cheatsheets (most unused) — keep `nixos/` subdir, delete rest |

### Path rename

| Before | After |
|---|---|
| Lokaler Pfad | `~/zaneyos` → `~/nixos-config` |
| GitHub repo | `Meo98/my-zaneyos-config` → `Meo98/nixos-config` |
| `modules/upstream/core/nh.nix` | `flake = "/home/${username}/nixos-config"` |

### flake.nix changes

- `description` → "MeoNix — Meo's NixOS configuration (meo + meo-work hosts)"
- Drop unused `nixosConfigurations`: `amd`, `nvidia`, `nvidia-laptop`, `amd-hybrid`, `amd-nvidia-hybrid`, `intel`, `vm` (these were zaneyos-template configs, not for us)
- Keep only `meo` and `meo-work`
- Update internal module paths to `modules/upstream/...`

## Stages with rollback points

Each stage commits separately. Rollback = `git reset --hard <previous-commit>`.

1. **Worktree setup + plan documentation** (this commit)
2. **Reorganize directory structure** (mv modules to upstream/, move custom to meo/)
3. **Update internal imports** (so flake still evaluates)
4. **Create `modules/meo/default.nix`** wiring up custom modules
5. **Update host imports** (hosts/meo/default.nix + hosts/meo-work/default.nix)
6. **Update flake.nix** (description, dropped configs, new internal paths)
7. **Update nh.nix path** (`/home/${username}/nixos-config`)
8. **Delete dead code**
9. **Write README.md + CLAUDE.md + docs/**
10. **Remove upstream git remote**
11. **Validation: `nh os build` for both hosts** (no switch)
12. **Merge to main + push**

## meo-work transition

After merge to main + push, meo-work needs:

```bash
cd ~/zaneyos
fr                       # auto-syncs latest (which has new structure)
# fr will fail or behave weirdly because nh.nix expects ~/nixos-config now

# Manual fix on meo-work (one-time):
cd ~
mv zaneyos nixos-config
cd nixos-config
fr                       # now works with new path
```

Document this prominently in README.md.

## How to sync upstream zaneyos in the future

The `upstream` remote was removed during this migration. To check on upstream changes:

```bash
git remote add zaneyos https://gitlab.com/zaney/zaneyos.git
git fetch zaneyos
git log --oneline main..zaneyos/main -- modules/  # what's new upstream

# Selectively port interesting changes manually:
git checkout zaneyos/main -- modules/upstream/some/path.nix    # nope, paths differ
# Better: read the diff and apply manually
git show zaneyos/main:modules/core/some-file.nix > /tmp/upstream.nix
diff modules/upstream/core/some-file.nix /tmp/upstream.nix
# then merge by hand
```

See `docs/SYNC_UPSTREAM.md` for the full workflow once written.

## Validation criteria

Migration is successful when:

- [ ] `nh os build --hostname nvidia-laptop` succeeds (meo)
- [ ] `nh os build --hostname meo-work` succeeds (meo-work)
- [ ] Both build outputs differ minimally from current `/run/current-system` (delta only structural, no semantic changes)
- [ ] `fr` on meo succeeds and system is unchanged behaviorally
- [ ] All custom modules present in `modules/meo/`
- [ ] No dangling imports
- [ ] Documentation files exist and are accurate
