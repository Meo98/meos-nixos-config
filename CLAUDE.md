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

### Trading Bot context

The user runs a live Rust trading bot (Matrix Quant) on the **meo** host. It's a systemd user service defined in `modules/meo/trading-bot.nix`. The service file points to `/home/meo/quant-trading-bot/rust/target/release/matrix_quant_core`.

**Don't break the meo host casually.** A failed rebuild = bot may stop. Always dry-build (`nh os build`) before suggesting `nh os switch` on meo. For risky changes, use the worktree pattern (see `docs/SYNC_UPSTREAM.md`).

### Affinity v3 setup

Lives in `hosts/meo/affinity.nix`. Imported by BOTH hosts (meo-work imports `../meo/affinity.nix`). Controlled by `enableAffinity = true|false` in respective `variables.nix`. Uses `pkgs.affinity-v3` from `inputs.affinity-nix` (github:mrshmllow/affinity-nix). Requires Garnix cache (already configured in `modules/upstream/core/cachix.nix`) — without it, wine compiles locally (hours).

## Common tasks

### "Add a package to system"

System-wide (both hosts): add to `modules/upstream/core/packages.nix` (mark as `# MODIFIED`).
Per-host: add to `hosts/{meo,meo-work}/host-packages.nix` `environment.systemPackages`.

### "Add a package to user (home-manager)"

If it's a shell tool with config: add to existing module in `modules/upstream/home/cli/`.
Custom/personal: add to `modules/meo/<name>.nix` as `home.packages = [ pkgs.foo ];`.

### "Add a new Hyprland keybinding"

`modules/upstream/home/hyprland/binds.nix` — keep changes minimal, mark with `# MODIFIED`.

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
