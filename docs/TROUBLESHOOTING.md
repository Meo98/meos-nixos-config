# Troubleshooting & Operations Manual

This is the file you read when something is broken or you forgot how something works.

It combines:
1. **Recent major changes** — what was modified, when, why (so you have context)
2. **Common problems & solutions** — sorted by symptom
3. **Recovery procedures** — when things really break
4. **Verification cheatsheet** — quick health checks

If you're an AI assistant arriving fresh: also read `CLAUDE.md` and `docs/ARCHITECTURE.md`.

---

## Recent major changes (2026-05-18)

### Timeline (in order)

| Time | Change | Commit | Rollback command |
|---|---|---|---|
| ~17:00 | Affinity migration: `path:/home/meo/affinity-nix-fork` → `github:mrshmllow/affinity-nix` (Garnix-cached) | `186d748` | `git revert 186d748` |
| ~19:00 | Clean Fork migration: modules/upstream + modules/meo split | `5498b22` | `git revert 5498b22` (BIG diff, careful) |
| ~20:00 | GitHub repo rename: `my-zaneyos-config` → `meos-nixos-config` | (GitHub UI) | `gh repo rename my-zaneyos-config --repo Meo98/meos-nixos-config` |
| ~20:00 | Local path rename: `~/zaneyos` → `~/nixos-config` (per host, manual) | n/a | `mv ~/nixos-config ~/zaneyos && nh os switch ~/zaneyos --hostname meo` |
| ~20:00 | README URL update | `a7c618d` | `git revert a7c618d` |
| ~20:50 | `_zsync` paths updated (~/zaneyos → ~/nixos-config) | `ad90eb6` | `git revert ad90eb6` |
| ~21:25 | 9 GitHub Actions workflows + dependabot + CI docs | `9ff9dac` | `git revert 9ff9dac` (just removes CI, doesn't break anything) |

### Key architectural decisions

**Why Clean Fork (modules/upstream + modules/meo) and not Flake Input?**
- zaneyos modules use `import ../../../../hosts/${host}/variables.nix` — **file-relative imports**
- These break when imported from `${inputs.zaneyos}/modules/...` because relative paths look for `${inputs.zaneyos}/hosts/${host}/variables.nix` which doesn't exist
- Workarounds (Augmented Input via Nix derivation, or Patched Fork on GitHub) add complexity for little gain
- See `docs/MIGRATION.md` for full rationale

**Why `nixosTarget = "meo"` instead of `"nvidia-laptop"`?**
- The OLD config had `nixosConfigurations.nvidia-laptop` (because nixosTarget defaulted to profile)
- We dropped the unused `nvidia-laptop`/`amd`/etc. configs, keeping only `meo` + `meo-work`
- Therefore `nixosTarget = "meo"` so `nh os switch --hostname meo` matches the surviving config
- The `fr` alias is `_zsync && nh os switch --hostname ${nixosTarget}` — it picks up the right name automatically

**Why `_zsync` is hardcoded to `~/nixos-config`?**
- It's a zsh function in `modules/upstream/home/zsh/default.nix:54-66` (modified by us, marked `# MODIFIED:`)
- If you ever rename the local dir again, search-and-replace `~/nixos-config` there + `programs.nh.flake` in `modules/upstream/core/nh.nix:12`

---

## Common problems & solutions

### 1. `fr` fails with "flake does not provide attribute 'nixosConfigurations.<X>'"

**Cause:** Your active shell session has an old `fr` alias hardcoded with a hostname that doesn't exist in flake.nix anymore.

**Most common trigger:** You just changed `nixosTarget` in flake.nix without restarting your shell.

**Fix:**
```bash
nh os switch --hostname meo .         # bypass the alias (or "meo-work" on the other host)
exec zsh                              # reload shell → new alias active
fr                                    # works now
```

### 2. `fr` fails with "fatal: cannot change to '/home/meo/zaneyos'"

**Cause:** Your active shell session has the OLD `_zsync` function in memory (with hardcoded `~/zaneyos` path), but the directory was renamed to `~/nixos-config`.

**Why it happens:** zsh functions are loaded at shell startup. `exec zsh` reloads them only if the new system has been activated. Right after a path-rename + rebuild, current sessions are stale.

**Fix:**
```bash
exec zsh    # reload the function from /etc/profiles/per-user/meo/etc/zshrc
fr          # works now
```

### 3. `nh os switch` fails with "getting status of '/home/meo/zaneyos': No such file or directory"

**Cause:** Your session has a stale `$NH_FLAKE` env var pointing at the renamed-away directory.

**Verify:** `echo $NH_FLAKE` shows `/home/meo/zaneyos` (old)

**Fix:**
```bash
# Quickest:
unset NH_FLAKE && nh os switch ~/nixos-config --hostname meo

# Better (persists for session):
export NH_FLAKE=$HOME/nixos-config
nh os switch --hostname meo

# Cleanest (permanent):
# Logout from graphical session and log back in — session vars are then refreshed from new system
```

`★ Insight: NH_FLAKE is set in /etc/profile.d/hm-session-vars.sh at LOGIN, not at shell start.
exec zsh doesn't refresh it. Only a full logout/login (or reboot) does.`

### 4. NixOS rebuild fails with "Path 'modules/home/..../X.nix' does not exist in Git repository"

**Cause:** Something in `hosts/` or another `.nix` file still references the OLD module path before the Clean Fork migration.

**Fix:** Search-and-replace:
```bash
grep -rn 'modules/home\b\|modules/core\b\|modules/drivers\b' hosts/ flake.nix
# For each match, replace with modules/upstream/home/, modules/upstream/core/, modules/upstream/drivers/
```

### 5. Trading bot didn't restart after reboot

**Cause:** systemd user service either wasn't enabled, or `default.target` didn't reach the user session.

**Verify:**
```bash
systemctl --user status matrix-quant.service
systemctl --user is-enabled matrix-quant.service   # should be 'enabled'
```

**Fix:**
```bash
systemctl --user enable matrix-quant.service
systemctl --user start matrix-quant.service
journalctl --user -u matrix-quant.service -n 50    # check for crash reasons
```

If the binary path is wrong (e.g., bot rebuilt elsewhere):
```bash
# Check what modules/meo/trading-bot.nix says:
grep -A1 "binary =" modules/meo/trading-bot.nix
# Update if needed, then `fr`
```

### 6. Affinity won't start / hangs ~30s

**Likely causes:**
- `enableAffinity` is false in `hosts/<host>/variables.nix` → flip to `true`, rebuild
- Canva-DNS-Block not active → check `cat /etc/hosts | grep canva` shows the 3 entries
- 32bit graphics stack missing → check `hardware.graphics.enable32Bit = true` is active (rebuild after enabling)
- Wine prefix corrupted → `rm -rf ~/.local/share/affinity-v3` and retry (loses Affinity user data)

**Diagnostic commands:**
```bash
which affinity-v3                           # should be /etc/profiles/per-user/meo/bin/affinity-v3
affinity-v3 --version                       # should print "runner 0.1.0"
affinity-v3 --verbose 2>&1 | head -50       # see what wine is doing
```

### 7. `nh os switch` builds Wine from source for hours

**Cause:** Garnix substituter not being used.

**Verify:**
```bash
nix show-config | grep substituter | grep garnix
# Should show https://cache.garnix.io
```

**Fix:** Look at `modules/upstream/core/cachix.nix` — Garnix should already be there. If not, add it:
```nix
nix.settings.substituters = lib.mkAfter [ "https://cache.garnix.io" ];
nix.settings.trusted-public-keys = lib.mkAfter [
  "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
];
```

Then rebuild. After activation, garnix is in your substituter list and the next Wine fetch is a cached download.

### 8. `_zsync` git pull fails with merge conflicts

**Cause:** Someone (you, or another host's auto-sync) pushed conflicting changes between your `fr` calls.

**Fix:**
```bash
cd ~/nixos-config
git status                  # see what's conflicting
git pull --rebase           # try to rebase your local changes on top
# Resolve conflicts manually if any
git rebase --continue       # after fixing
fr                          # retry
```

If totally stuck:
```bash
git stash
git pull
git stash pop               # may have conflicts, resolve, commit
```

### 9. GitHub Action workflow fails with "Workflow permissions" error

**Cause:** Repo settings don't allow Actions to create PRs/issues.

**Fix (preferred — one-shot via API):**
```bash
gh api -X PUT repos/Meo98/meos-nixos-config/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
# Verify:
gh api repos/Meo98/meos-nixos-config/actions/permissions/workflow
```

**Fix (alternative — in GitHub UI):**
- Settings → Actions → General → "Workflow permissions"
- Select "Read and write permissions"
- Check "Allow GitHub Actions to create and approve pull requests"

Then re-run the failing workflow.

### 9b. `flake-update.yml` fails with "Failed to fetch git repository 'https://codeberg.org/...'" or HTTP 503

**Cause:** Codeberg.org is temporarily down. They have outages occasionally. Until codeberg is back, no `nix flake update` will succeed because awww input is hosted there.

**Verify:**
```bash
curl -sI https://codeberg.org/ | head -1   # if not "HTTP/2 200" → codeberg outage
```

**Fix:** Just wait (usually hours, rarely days). Re-trigger:
```bash
gh workflow run "Update flake inputs" --repo Meo98/meos-nixos-config
```

**Permanent fix (only if codeberg-outages get frequent):** Replace the awww input with a github mirror in `flake.nix` — but currently awww has no official github mirror, you'd have to fork.

### 10. `flake-update.yml` PR doesn't appear on Monday morning

**Possible causes & fixes:**

| Cause | Fix |
|---|---|
| Workflow permissions not set | Settings → Actions → permissions (above) |
| nixpkgs hasn't changed | Working as intended — no PR if no updates |
| Workflow was disabled | `gh workflow enable "Update flake inputs"` |
| Token expired (rare) | Re-trigger manually: `gh workflow run "Update flake inputs"` |

### 11. Hyprland keybindings (volume/brightness) don't work after rebuild

**Cause:** Custom scripts `vol-smart`/`bright-smart` not in PATH or modules/meo broken import.

**Verify:**
```bash
which vol-smart bright-smart      # should find both in ~/.nix-profile/bin
hyprctl binds | grep -E "vol-smart|bright-smart"   # active bindings
```

**Likely root causes:**
- `modules/meo/default.nix` doesn't import `./scripts.nix` and/or `./hyprland.nix`
- `hosts/<host>/default.nix` doesn't import `modules/meo` via `home-manager.users.${username}.imports`

Both should be there since the Clean Fork migration. If missing, check git log: `git log --oneline --all -- modules/meo/default.nix`.

### 12. Bluetooth audio monitor service not running

**Cause:** `bt-audio-monitor` is registered in `modules/upstream/home/noctalia.nix` line 10 as `import ../../meo/scripts/bt-audio-monitor.nix`. If that path breaks, the service can't start.

**Verify:**
```bash
systemctl --user status bt-audio-monitor.service
ls modules/meo/scripts/bt-audio-monitor.nix     # exists?
```

**Fix:** Restore the correct path:
```bash
grep -n "bt-audio-monitor" modules/upstream/home/noctalia.nix
# Should be: bt-audio-monitor = import ../../meo/scripts/bt-audio-monitor.nix {inherit pkgs;};
```

---

## Recovery procedures

### "System won't boot" (worst case)

1. At the GRUB boot menu, select **a previous NixOS generation** (older list entry)
2. Boot into it — you have a working system
3. Diagnose what broke in the failing config:
   ```bash
   journalctl -b -1 -p err     # errors from last boot attempt
   ```
4. Fix the config, rebuild, reboot

### "Trading bot is down and I need it back NOW"

```bash
# Manual restart:
systemctl --user restart matrix-quant.service

# If service definition is broken:
cd /home/meo/quant-trading-bot/rust
nohup ./target/release/matrix_quant_core > /tmp/matrix_quant.log 2>&1 &
# Bot is running ad-hoc (not via systemd) — fix the service def later
```

### "Repo is in a horrible state, want to restart fresh"

```bash
cd ~
mv nixos-config nixos-config.broken
git clone https://github.com/Meo98/meos-nixos-config.git nixos-config
cd nixos-config
nh os switch --hostname meo .
```

Then cherry-pick anything you need from `nixos-config.broken/` if it had unsaved local changes.

### "I made a bad change and pushed it, both hosts are at risk"

```bash
# Quick revert:
git revert HEAD --no-edit
git push origin main
# Both hosts pick this up on next `fr`

# Or: roll back to a specific known-good commit:
git reset --hard <known-good-sha>
git push origin main --force-with-lease    # CAREFUL: force-pushes
```

If meo-work already pulled the bad change and rebuilt:
- On meo-work: select previous GRUB generation, boot into it
- On meo-work: pull the revert, `fr`

---

## Verification cheatsheet (run these after major changes)

```bash
# Full health check — run after any rebuild
cd ~/nixos-config

# 1. Git state clean?
git status                                                  # working tree clean
git log --oneline -3                                       # latest commits look right

# 2. Env vars correct?
echo $NH_FLAKE                                              # should be /home/meo/nixos-config

# 3. Activated system matches latest config?
readlink /run/current-system                                # should be a recent /nix/store path
nixos-version                                               # NixOS version

# 4. Trading bot running?
systemctl --user is-active matrix-quant.service             # active

# 5. Custom scripts in PATH?
for cmd in affinity-v3 vol-smart bright-smart bt-audio-switch bt-audio-monitor travel-power; do
  printf "%-25s " "$cmd:"; which "$cmd" 2>/dev/null || echo "MISSING"
done

# 6. Flake evaluates?
nix flake check --no-build 2>&1 | tail -3                  # "all checks passed!"

# 7. Remote is correct?
git remote -v                                               # origin = meos-nixos-config, no upstream

# 8. Latest GitHub workflows passing?
gh run list --repo Meo98/meos-nixos-config --limit 5       # all "completed success" recently
```

If any of these is wrong → see the corresponding section above.

---

## Pending follow-ups (from 2026-05-18 session)

- [ ] **meo-work**: do the same path-rename + reboot dance there (see "Migration sequence on meo-work" in `docs/MIGRATION.md`)
- [ ] **GitHub Settings → Actions permissions**: enable "Read and write" + "Allow PR creation" so `flake-update.yml` works
- [ ] **(Optional) Branch protection on main**: require `build.yml` + `check.yml` to pass before merge (paranoia mode for trading bot stability)
- [ ] **(Optional) `automerge.yml`**: review whether you want flake-update PRs to auto-merge — currently OFF by default, opt-in via label

---

## Quick reference: where things live

| Need to... | Look in |
|---|---|
| Add a personal package/script | `modules/meo/scripts/<name>.nix` + add to `modules/meo/scripts.nix` |
| Add Hyprland binding | `modules/upstream/home/hyprland/binds.nix` (mark `# MODIFIED`) |
| Change keyboard layout | `hosts/<host>/variables.nix` → `keyboardLayout` + `consoleKeyMap` |
| Toggle Affinity | `hosts/<host>/variables.nix` → `enableAffinity = true/false` |
| Add overlay | `modules/meo/<name>.nix` + import in `hosts/<host>/host-packages.nix` |
| Change Trading Bot path | `modules/meo/trading-bot.nix` line 2-3 |
| Update fr alias behavior | `modules/upstream/home/zsh/default.nix` line 76 (mark `# MODIFIED`) |
| Sync zaneyos upstream | See `docs/SYNC_UPSTREAM.md` |
| Understand CI workflows | See `docs/CI.md` |
| Get oriented as new AI assistant | Read `CLAUDE.md` first |
