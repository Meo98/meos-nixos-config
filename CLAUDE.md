# Context for Claude (and other AI assistants)

This file gives you the context you need to work efficiently in this NixOS configuration repo.

## TL;DR architecture

```
modules/
├── meo/         ← User's custom code. Touch this freely.
└── upstream/    ← Vendored from zaneyos (gitlab.com/zaney/zaneyos).
                   Touch only if change is wanted on both hosts.
                   Mark modifications with comment `# MODIFIED: <reason>`.
```

Two hosts: `meo` (home, nvidia-laptop profile) and `meo-work` (Intel iGPU).

## Critical paths and gotchas

### Path-relative imports in modules/upstream/

zaneyos modules use `import ../../../../hosts/${host}/variables.nix` pattern (path-relative). When you move/rename a module within `modules/upstream/`, count `../` carefully — wrong depth = build fails with "path does not exist". The depth is from the file's location to repo root, then back down into `hosts/${host}/`.

This was the **fundamental reason** we chose Clean Fork over Flake-Input pattern — modules can't be loaded from /nix/store with their original path-relative imports working. See `docs/MIGRATION.md` section "Investigation".

### Custom modules (`modules/meo/`)

When user says "add a new module", default to `modules/meo/`:
- Pure NixOS module → `modules/meo/<name>.nix`, import from `hosts/{meo,meo-work}/default.nix` or `modules/meo/default.nix`.
- Home-manager module → `modules/meo/<name>.nix`, import from `modules/meo/default.nix` (already wired into HM context via hosts).
- Package/script → put as derivation in `modules/meo/scripts/<name>.nix`, add to `home.packages` list in `modules/meo/scripts.nix`.
- Overlay → put in `modules/meo/<name>.nix`, import from `hosts/*/host-packages.nix` as `(import ../../modules/meo/<name>.nix)`.

### Auto-sync behavior (`fr` and `_zsync`)

The `fr` alias does `_zsync && nh os switch --hostname <nixosTarget>`. `_zsync` is a zsh function that:
1. `git pull`
2. `git commit -am "auto-sync from $(hostname) $(date)"` (auto-commits dirty state)
3. `git push`

**Implication for you:** any file you modify in the working tree will get auto-committed to GitHub next time the user runs `fr`. There's no "scratch / WIP" zone — if you don't want it shipped to both hosts, don't edit it in this repo.

### nixosTarget vs profile vs hostname

In `flake.nix`:
- `host` = directory under `hosts/` (e.g., `meo`, `meo-work`)
- `profile` = directory under `modules/upstream/profiles/` (e.g., `nvidia-laptop`, `intel`)
- `nixosTarget` = the nixosConfigurations name AND what `fr` passes as `--hostname` to nh
- These can differ! `meo` host runs `profile=nvidia-laptop` but `nixosTarget=meo`.

If you add a new host, set ALL THREE.

### Trading Bot context (HISTORICAL — bot retired 2026-07-16)

The Matrix Quant trading bot no longer exists: user decided it's not needed. `modules/meo/trading-bot.nix` was deleted (history: `git log --follow`). Consequently `flake-update.yml` PRs now carry the `automerge` label — weekly updates merge automatically once `build.yml` is green on both hosts.

Dry-building both hosts before pushing is still good practice, but there is no live service that a failed rebuild would take down anymore.

### Affinity v3 setup

Lives in `hosts/meo/affinity.nix`. Imported by BOTH hosts (meo-work imports `../meo/affinity.nix`). Controlled by `enableAffinity = true|false` in respective `variables.nix`. Uses `pkgs.affinity-v3` from `inputs.affinity-nix` — seit 2026-10-13 wieder **upstream `github:mrshmllow/affinity-nix`** mit `inputs.nixpkgs.follows` (der frühere Fork `Meo98/affinity-nix-fork` pinnte ein altes nixpkgs-Wine, dessen glibc die Host-Mesa/Vulkan-Libs nicht laden konnte; Details im Kommentar in `flake.nix`). Garnix (`cache.garnix.io`) ist seit 2026-10 tot (NXDOMAIN) und wurde aus `cachix.nix` und `build.yml` entfernt. wine-wow64 und der Base-Prefix liegen in keinem Binary-Cache, müssen einmalig lokal kompiliert werden (≈ 20-30 Min beim ersten Build pro Host). CI baut Affinity **nicht**: `build.yml` baut die `nixosConfigurations.<host>-ci`-Varianten (flake.nix, `ci = true` specialArg), in denen `affinity.nix` sich selbst deaktiviert. Grund: wine-wow64 braucht auf dem 2-Core-Runner über 60 Min (Run #191 lief zusätzlich voll, Run 37601965808 ins Timeout). Affinity-Änderungen also immer lokal mit `nh os build` prüfen.

Hybrid-GPU-Falle auf `meo` (2026-10-14): wined3d läuft im Prefix mit `renderer=vulkan` und nimmt den ERSTEN Vulkan-Adapter (Intel iGPU), während niri im Dock-Modus auf der NVIDIA rendert → D3D11-Swapchain scheitert, Affinity zeigt leeren Canvas und reagiert nicht mehr (`Failed to create Direct3D device ... 0x8007000E`). Deshalb installiert `affinity.nix` nicht `pkgs.affinity-v3` direkt, sondern den Wrapper `affinity-v3-gpu`, der `MESA_VK_DEVICE_SELECT` aus dem `render-drm-device` in `~/.config/niri/.niri-smart.kdl` (niri-gpu-smart) ableitet und auch den Desktop-Eintrag umbiegt. Debuggen: Wine-Meldungen landen nicht im Journal, nur `affinity-v3 --verbose > datei` im Terminal zeigt sie.

### Claude Code integration (`modules/meo/claude-code.nix`)

Since 2026-10-12 the home-manager module `programs.claude-code` is enabled on both hosts:

- **mcp-nixos** MCP server (`pkgs.mcp-nixos`, tools `nix` / `nix_versions`) for live
  lookup of nixpkgs packages, NixOS/home-manager options and package version history.
  Use it instead of guessing package or option names. It does NOT know this config;
  use `nix eval .#nixosConfigurations.<host>.config.<option>` for local values.
- **Global `~/.claude/CLAUDE.md`** is a store symlink to `modules/meo/claude-global.md`
  (rebuild rules, declarative-only policy). Edit it in the repo, not in `~/.claude/`.
- `package = null` on purpose: the `claude-code` binary stays in `hosts/*/host-packages.nix`.
- `settings`, `plugins`, `marketplaces` are intentionally NOT managed by home-manager.
  Setting any of them turns `~/.claude/settings.json` into a read-only store symlink and
  breaks the imperative `/plugin install` workflow the user relies on.

## Common tasks

### "Add a package to system"

System-wide (both hosts): add to `modules/upstream/core/packages.nix` (mark as `# MODIFIED`).
Per-host: add to `hosts/{meo,meo-work}/host-packages.nix` `environment.systemPackages`.

### "Add a package to user (home-manager)"

If it's a shell tool with config: add to existing module in `modules/upstream/home/cli/`.
Custom/personal: add to `modules/meo/<name>.nix` as `home.packages = [ pkgs.foo ];`.

### "Add a new keybinding"

Since the niri migration (`meo`: 2026-08-27, `meo-work`: 2026-08-31), no host boots into
Hyprland by default anymore — it's a fallback session only, selectable in the display
manager. New binds go into `modules/meo/niri/binds-nav.nix` (navigation/window
management) or `modules/meo/niri/binds-apps.nix` (app launchers), whichever fits.

`modules/upstream/home/hyprland/binds.nix` still exists for the Hyprland fallback —
keep changes minimal, mark with `# MODIFIED`, only touch it when the bind must also
work under the Hyprland rollback session.

### "Sync zaneyos upstream"

See `docs/SYNC_UPSTREAM.md`. TL;DR: `git remote add zaneyos https://gitlab.com/zaney/zaneyos.git`, fetch, manually cherry-pick interesting commits into `modules/upstream/`.

### "Make a change just for one host"

Edit `hosts/<host>/default.nix` or `hosts/<host>/variables.nix`. Don't put per-host logic in `modules/`.

## Anti-patterns to avoid

- ❌ Don't add `git remote add upstream` — we severed that relationship intentionally.
- ❌ Don't try to make `modules/upstream/` a Flake input — the path-relative imports break this. See `docs/MIGRATION.md`.
- ❌ Don't push to main without dry-building both hosts first (`nh os build --hostname meo` AND `--hostname meo-work`).
- ❌ Don't delete `modules/upstream/profiles/<unused>/` without checking flake.nix doesn't reference it.
- ❌ Don't rename `~/nixos-config` without updating `modules/upstream/core/nh.nix` (`flake = "/home/${username}/nixos-config";`).

## When stuck

**START HERE:** [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — covers all known failure modes from the 2026-05-18 session (NH_FLAKE stale, fr alias mismatch, path-rename traps, Stylix IFD on CI, etc.) plus recovery procedures.

Quick diagnostics:
- Build errors usually point to a relative path that's wrong (check `../` count) or a stale reference to a moved file.
- `nix flake check .` works locally (cached palette) but FAILS on fresh CI due to Stylix IFD — that's why `check.yml` workflow was removed; use `build.yml` for CI validation.
- For history of any module: `git log --follow modules/upstream/<path>` — git mv preserved history through the migration.
