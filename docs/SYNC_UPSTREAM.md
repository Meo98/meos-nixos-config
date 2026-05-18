# Syncing upstream zaneyos changes

After the 2026-05-18 Clean Fork migration, we no longer track upstream via `git remote upstream`. This is intentional — we own the code now. But upstream zaneyos keeps evolving, and sometimes there are useful changes worth porting.

This doc explains how to do that cleanly, without merge hell.

## One-time setup

```bash
cd ~/nixos-config
git remote add zaneyos https://gitlab.com/zaney/zaneyos.git
git fetch zaneyos
```

Note: we call it `zaneyos`, not `upstream`. The old `upstream` remote was the *fork* relationship (us being downstream). The new `zaneyos` remote is just a *reference* — we look at what they're doing, we don't merge.

## Periodic check — what's new upstream?

```bash
git fetch zaneyos
git log --oneline main..zaneyos/main -- modules/ profiles/
```

This shows commits since you last checked, scoped to modules/ and profiles/ (the parts you might want to port). Skip commits that are pure docs (FAQ, CHANGELOG) or installer fixes (install-zaneyos.sh, zcli.nix).

Alternatively, automate via systemd timer (see `modules/meo/scripts/upstream-digest.sh` — TODO, not written yet).

## Classify and decide what to port

For each interesting commit:

```bash
git show zaneyos/<commit-sha> --stat
git show zaneyos/<commit-sha> -- modules/   # see the actual changes scoped to modules
```

Decide:
- **Port it** → continue below
- **Skip it** → write a one-liner in a `docs/UPSTREAM_SKIPPED.md` so you don't reconsider it next time
- **Maybe later** → leave it, you'll see it again next check

## Porting a single upstream change

zaneyos's module layout is `modules/...`, ours is `modules/upstream/...`. Files differ by 1 level of nesting, so relative paths inside the file might need `+1 ../`.

### Workflow for a small change (single file, few lines):

```bash
# 1. See what zaneyos changed:
git show zaneyos/<sha> -- modules/core/some-file.nix

# 2. Apply manually to your version:
$EDITOR modules/upstream/core/some-file.nix

# 3. If the change touched a relative path going up:
#    e.g. zaneyos changed `../../hosts/${host}/variables.nix` to add `../`
#    you need to apply the same change but with our depth (+1):
#    `../../../hosts/${host}/variables.nix` → `../../../../hosts/${host}/variables.nix`

# 4. Build to verify:
nh os build --hostname meo
nh os build --hostname meo-work

# 5. If both green, commit:
git add modules/upstream/core/some-file.nix
git commit -m "port: upstream <sha> — <short description>"
```

### Workflow for a larger change (many files, refactoring):

```bash
# 1. Create a worktree for safe experimentation:
git worktree add ../nixos-config-port port/upstream-<theme>

# 2. cd into it and apply the changes
cd ../nixos-config-port

# 3. Use git checkout to bring in specific files from zaneyos:
git checkout zaneyos/main -- modules/some/path.nix
# (this is risky because paths might differ — use as starting point only)

# 4. Manually adjust path-relative imports for our nesting

# 5. Build, test, iterate

# 6. When ready, merge back:
cd ~/nixos-config
git merge --no-ff port/upstream-<theme>
git worktree remove ../nixos-config-port
git branch -D port/upstream-<theme>

# 7. Push:
fr   # auto-sync + rebuild
```

## What you definitely shouldn't port

These upstream changes don't apply to us anymore:
- Changes to `install-zaneyos.sh` (deleted)
- Changes to `zcli.nix` (we use nh, not zcli — wait, actually we still have it; check if you removed it)
- Changes to `FAQ.md`, `CHANGELOG.md`, `WARP.md`, `CONTRIBUTING.md` (deleted)
- Changes to `hosts/default/`, `hosts/zaneyos-{24-vm,oem}/` (deleted)
- Changes to `profiles/{amd,nvidia,vm,amd-hybrid,amd-nvidia-hybrid}/` (deleted — we only have nvidia-laptop + intel)
- TUI display manager defaults (we use SDDM)

## Marking modifications

When you modify a file in `modules/upstream/` (either porting or your own custom change), add a comment:

```nix
{ pkgs, ... }: {
  services.foo = {
    enable = true;
    # MODIFIED: added bar=true for Trading Bot compat (2026-06-15)
    bar = true;
  };
}
```

Then next time you sync upstream and they changed the same area, `git log -p modules/upstream/.../that-file.nix` shows you the marker and you know to be careful.

## Detecting drift — how outdated is my upstream/?

```bash
# How many upstream commits since we last did a major sync:
git fetch zaneyos
git log --oneline main..zaneyos/main -- modules/ | wc -l

# What did upstream change in a specific file we modified?
git log zaneyos/main -- modules/core/<file>.nix
```

If the count gets large (>30), consider a dedicated sync session. If small, just port what's interesting.

## Why we don't auto-merge

We chose Clean Fork over "Friendly Fork" (periodic git merge upstream) because:

1. Our `modules/` path differs from theirs by one level — every merge would conflict on every file.
2. We've already modified ~96 files vs upstream — manual conflict resolution is unavoidable, automating it just creates a false sense of safety.
3. Cherry-picking specific commits forces us to consciously decide what we want — preferred over surprise behavior changes.

If this approach becomes painful (more than ~3h per quarter), consider:
- Moving to the **Augmented Input** pattern (see `docs/MIGRATION.md` Option A) — but this requires Nix derivation magic that's hard to debug.
- Becoming a true zaneyos consumer (revert this migration, run pure zaneyos with thin override layer) — only worth it if you stop modifying zaneyos modules.
- Going full custom (delete `modules/upstream/`, write everything yourself) — months of work for the same outcome.
