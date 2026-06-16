# Terminal Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Kitty+Powerlevel10k with Ghostty+Starship on the `meo` host, and add modern CLI replacements (zoxide, atuin) on top of the already-enabled `eza` and `bat`.

**Architecture:** Single new Home-Manager module (`modules/meo/cli-modern.nix`) wires Starship+zoxide+atuin. Two upstream module edits (with `# MODIFIED:` tag per CLAUDE.md): drop p10k from `zsh/default.nix`, switch bat theme. Two variable flips in `hosts/meo/variables.nix` (`terminal`, `ghosttyEnable`). Kitty stays installed as a safety fallback.

**Tech Stack:** NixOS, Home-Manager, Nix flakes, `nh` (nix-helper), `zsh`, Ghostty, Starship, zoxide, atuin.

**Spec:** `docs/superpowers/specs/2026-06-16-terminal-modernization-design.md`

**Critical safety note (from CLAUDE.md):** The `meo` host runs a live Rust trading bot as a systemd user service. **Always `nh os build --hostname meo` before `nh os switch`** — a failed rebuild can stop the bot. The `_zsync`/`fr` flow auto-commits and pushes dirty state, so never leave a broken file in the working tree.

---

## File Structure

| File | Purpose | Action |
|---|---|---|
| `modules/meo/cli-modern.nix` | Enable Starship, zoxide, atuin (Home-Manager) | **Create** |
| `modules/meo/default.nix` | Wire the new module into HM imports | **Modify**: add 1 import line |
| `modules/upstream/home/zsh/default.nix` | Remove p10k plugin block | **Modify** (+ `# MODIFIED:` tag) |
| `modules/upstream/home/cli/bat.nix` | Switch theme Dracula → Catppuccin Mocha | **Modify** (+ `# MODIFIED:` tag) |
| `hosts/meo/variables.nix` | `terminal = "ghostty"`, `ghosttyEnable = true` | **Modify**: 2 lines |
| `hosts/meo-work/variables.nix` | NOT touched — work host keeps Kitty | (unchanged) |

`modules/upstream/home/starship.nix` is **not** edited directly. It already sets `programs.starship.enable = false`, and the new `cli-modern.nix` overrides that with `lib.mkForce true`. This keeps the upstream file pristine for future zaneyos syncs.

`p10k-config/p10k.zsh` is left in place (orphaned, harmless) — deleting it is out-of-scope cleanup.

---

## Task 1: Create `modules/meo/cli-modern.nix`

**Files:**
- Create: `modules/meo/cli-modern.nix`
- Modify: `modules/meo/default.nix` (add one import)

- [ ] **Step 1: Create the new module**

Create `modules/meo/cli-modern.nix` with this exact content:

```nix
# Modern CLI stack: Starship prompt + zoxide (smart cd) + atuin (history).
# eza and bat are already enabled via modules/upstream/home/{eza.nix,cli/bat.nix}.
{
  lib,
  pkgs,
  ...
}: {
  # Starship — override the upstream `enable = false` default.
  programs.starship = {
    enable = lib.mkForce true;
    enableZshIntegration = true;
    # Catppuccin Mocha palette (matches Ghostty + Neovim theme).
    settings = {
      add_newline = false;
      palette = "catppuccin_mocha";
      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };

  # zoxide — smarter cd. Use with `z <hint>` or `zi` (interactive).
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # atuin — shell history with fzf-style picker. Local only; no cloud sync.
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = ["--disable-up-arrow"]; # keep zsh's up-arrow recall; only rebind Ctrl+R
    settings = {
      auto_sync = false;
      update_check = false;
      sync_frequency = "0";
      style = "compact";
      inline_height = 20;
      show_preview = true;
      keymap_mode = "vim-insert";
    };
  };
}
```

- [ ] **Step 2: Wire it into `modules/meo/default.nix`**

Add `./cli-modern.nix` to the imports list. The current file is:

```nix
{
  # Custom home-manager modules added on top of modules/upstream/home/.
  # This file is imported via hosts/{meo,meo-work}/default.nix as:
  #   home-manager.users.${username}.imports = [ ../../modules/meo ];
  imports = [
    ./trading-bot.nix
    ./hyprland.nix
    ./scripts.nix
    ./pdf-tools.nix
    ./cad-tools.nix
    ./nvim-yazi-tweaks.nix
    ./bun.nix
  ];
}
```

Use `Edit` to add `./cli-modern.nix` after `./bun.nix`. Final imports list:

```nix
  imports = [
    ./trading-bot.nix
    ./hyprland.nix
    ./scripts.nix
    ./pdf-tools.nix
    ./cad-tools.nix
    ./nvim-yazi-tweaks.nix
    ./bun.nix
    ./cli-modern.nix
  ];
```

Note: `modules/meo/default.nix` is imported by BOTH `hosts/meo/default.nix` and `hosts/meo-work/default.nix`. So this module activates on both hosts. That is fine and desired — Starship/zoxide/atuin are work-safe.

- [ ] **Step 3: Dry-build to catch eval errors (no switch)**

Run from `~/nixos-config`:

```bash
nh os build --hostname meo
```

Expected: completes without errors. If it fails with "attribute … missing" → check spelling of `programs.starship.settings.palettes.catppuccin_mocha`. If it fails with "infinite recursion" → re-check `lib.mkForce` placement.

Also dry-build the work host (CLAUDE.md anti-pattern: don't push to main without dry-building both):

```bash
nh os build --hostname meo-work
```

Expected: both succeed.

- [ ] **Step 4: Commit**

```bash
cd ~/nixos-config
git add modules/meo/cli-modern.nix modules/meo/default.nix
git commit -m "feat(cli): add Starship + zoxide + atuin (cli-modern module)

- Starship with Catppuccin Mocha palette overrides upstream enable=false
- zoxide and atuin enabled with zsh integration
- atuin local-only (auto_sync=false, no cloud)
- atuin keeps up-arrow on zsh history; rebinds Ctrl+R only

eza and bat are already enabled via upstream modules.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

Do NOT switch yet. The system still uses p10k as the prompt — switching now would run both p10k AND starship at shell init (works, but ugly). The next task removes p10k.

---

## Task 2: Remove Powerlevel10k from upstream zsh module

**Files:**
- Modify: `modules/upstream/home/zsh/default.nix:32-43`

- [ ] **Step 1: Edit `modules/upstream/home/zsh/default.nix`**

Current content at lines 32-43:

```nix
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = lib.cleanSource ./p10k-config;
        file = "p10k.zsh";
      }
    ];
```

Replace the whole `plugins = [ … ];` block with:

```nix
    # MODIFIED 2026-06-16: dropped powerlevel10k in favor of Starship
    # (see modules/meo/cli-modern.nix). p10k-config/ directory left in place
    # as orphan and can be cleaned up later.
    plugins = [];
```

Use the `Edit` tool with the exact `old_string` matching the current block (above) and the `new_string` shown.

- [ ] **Step 2: Dry-build both hosts**

```bash
cd ~/nixos-config
nh os build --hostname meo && nh os build --hostname meo-work
```

Expected: both succeed. The `lib` argument is still used elsewhere in the file (check via `grep '\blib\b' modules/upstream/home/zsh/default.nix`); if not, no action — leaving unused function args in a Nix module is harmless.

- [ ] **Step 3: Commit**

```bash
cd ~/nixos-config
git add modules/upstream/home/zsh/default.nix
git commit -m "refactor(zsh): drop powerlevel10k plugin block (use Starship)

MODIFIED tag added in module. Starship is wired via modules/meo/cli-modern.nix.
The orphaned modules/upstream/home/zsh/p10k-config/ directory is left in place
for now; it costs nothing and can be removed in a later cleanup.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Switch bat theme to Catppuccin Mocha

**Files:**
- Modify: `modules/upstream/home/cli/bat.nix`

- [ ] **Step 1: Edit `modules/upstream/home/cli/bat.nix`**

Current line:

```nix
      theme = lib.mkForce "Dracula";
```

Replace with:

```nix
      # MODIFIED 2026-06-16: Dracula → Catppuccin Mocha for theme consistency
      # with Ghostty + Neovim + Starship.
      theme = lib.mkForce "Catppuccin Mocha";
```

The theme name must match a theme bundled with the `bat` package. Recent `bat` versions (≥ 0.24) bundle all four Catppuccin variants. If the build later complains "Unknown theme 'Catppuccin Mocha'", verify available themes after switch with:

```bash
bat --list-themes | grep -i catppuccin
```

…and adjust the theme string to whatever it prints (e.g., `"Catppuccin-mocha"`).

- [ ] **Step 2: Dry-build both hosts**

```bash
cd ~/nixos-config
nh os build --hostname meo && nh os build --hostname meo-work
```

Expected: both succeed. (Nix evaluation does not validate the bat theme string — only runtime will.)

- [ ] **Step 3: Commit**

```bash
cd ~/nixos-config
git add modules/upstream/home/cli/bat.nix
git commit -m "style(bat): switch theme Dracula -> Catppuccin Mocha

Aligns bat with the rest of the Catppuccin Mocha stack (Ghostty, Neovim, Starship).
MODIFIED tag added per CLAUDE.md upstream-edit convention.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Flip terminal variables on `meo` host

**Files:**
- Modify: `hosts/meo/variables.nix:17` and `:71`

- [ ] **Step 1: Set `ghosttyEnable = true`**

Current line 17:

```nix
  ghosttyEnable = false;
```

Replace with:

```nix
  ghosttyEnable = true;
```

- [ ] **Step 2: Set `terminal = "ghostty"`**

Current line 71:

```nix
  terminal = "kitty"; # Set Default System Terminal
```

Replace with:

```nix
  terminal = "ghostty"; # Set Default System Terminal
```

Do NOT touch `hosts/meo-work/variables.nix`. The work host keeps Kitty.

- [ ] **Step 3: Dry-build both hosts**

```bash
cd ~/nixos-config
nh os build --hostname meo && nh os build --hostname meo-work
```

Expected: both succeed. The `meo` build now includes Ghostty in the user profile; the `meo-work` build is unchanged.

- [ ] **Step 4: Commit**

```bash
cd ~/nixos-config
git add hosts/meo/variables.nix
git commit -m "feat(meo): switch default terminal Kitty -> Ghostty

Sets ghosttyEnable=true and terminal=\"ghostty\" on the meo host only.
Kitty stays installed as a fallback. Hyprland's \$mainMod+Return binding
auto-picks up the new value via \$terminal.

meo-work is unchanged.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Activate on `meo` and smoke-test

**Files:** None (runtime activation).

- [ ] **Step 1: Final dry-build before switch**

```bash
cd ~/nixos-config
nh os build --hostname meo
```

Expected: success. If it fails, STOP — do not switch. Investigate the error and fix before proceeding.

- [ ] **Step 2: Activate**

```bash
cd ~/nixos-config
nh os switch --hostname meo
```

Expected: activation succeeds, no service restart errors related to the trading bot. The CURRENT shell still shows the OLD prompt — that's expected; Home-Manager rewrites config files but doesn't kill running shells.

- [ ] **Step 3: Open a new shell and verify Starship**

Open a fresh terminal (any way: new Kitty window, `zsh -l` in current shell, etc.).

Expected: prompt is Starship (no Powerline triangles, simpler look, possibly multi-line). If you see the old P10k prompt → the shell's `~/.zshrc` is stale; run `exec zsh` to reload.

If Starship is broken (e.g., `command not found: starship`):
```bash
which starship  # should print /etc/profiles/per-user/meo/bin/starship
```
If empty → cli-modern.nix import didn't take effect; check `~/.config/zsh/.zshrc` for the starship init line.

- [ ] **Step 4: Verify Ghostty starts via Hyprland binding**

Press `Mod+Return` (the Hyprland super+Return key). Expected: a Ghostty window opens (not Kitty). Visually distinct: cursor warp shader animation, `alt+s` leader keybinds for tabs/splits.

If Kitty opens instead → Hyprland was not restarted with the new env. Restart Hyprland (or reboot) and retry. Alternatively, run `pgrep -af ghostty` in any terminal to confirm the binary exists.

- [ ] **Step 5: Smoke-test the CLI tools**

In a fresh shell, run each and visually confirm:

```bash
ls                                          # eza output with icons
cat ~/nixos-config/flake.nix | head -5      # bat: syntax-highlighted, Catppuccin Mocha colors
cd ~/nixos-config && cd ~                   # warm zoxide
z nixos                                     # should jump back to ~/nixos-config
# Now press Ctrl+R                          # atuin fzf-style picker should appear (not bash-style i-search)
```

If `z nixos` says "command not found" → zoxide's zsh init didn't run. Check `~/.config/zsh/.zshrc` contains `eval "$(zoxide init zsh)"` or equivalent.

If Ctrl+R shows the OLD i-search → atuin's bindkey didn't run. Check it loaded with `atuin --version` and try `bindkey | grep atuin`.

- [ ] **Step 6: Verify Kitty fallback still works**

```bash
kitty &
```

Expected: a Kitty window opens. This confirms the safety net is intact.

- [ ] **Step 7: Verify the trading bot is healthy**

```bash
systemctl --user status matrix-quant
```

(Unit name verified from `modules/meo/trading-bot.nix:5` — `systemd.user.services.matrix-quant`.)

Expected: `active (running)`. If failed → THIS IS A PROBLEM. Roll back immediately (see Rollback section).

- [ ] **Step 8: Push to origin**

The `_zsync`/`fr` flow normally handles this, but commits were made manually during this plan. Run:

```bash
cd ~/nixos-config && git push
```

Expected: 4 new commits pushed (`cli-modern`, `zsh`, `bat`, `variables`).

---

## Rollback Procedure

If anything goes wrong at Step 7 (trading bot down) or any step fails:

### Soft rollback (NixOS generation)
```bash
nh os rollback
```
Reverts to the prior generation; trading bot resumes. Does not touch git.

### Git rollback (undo the 4 commits without losing work)
```bash
cd ~/nixos-config
git reset --soft HEAD~4   # uncommits, keeps changes in working tree
# Now inspect & fix
```
or hard (only if you're certain you want to discard):
```bash
git reset --hard HEAD~4
```
Then `nh os switch --hostname meo` to confirm pre-change state.

### Partial rollback — keep CLI tools, revert terminal/prompt
Edit `hosts/meo/variables.nix`: `terminal = "kitty"`, `ghosttyEnable = false`. Re-add the p10k plugin block to `modules/upstream/home/zsh/default.nix`. Build, switch. Starship/zoxide/atuin remain installed but Starship is overridden back to default by the upstream `enable = false` (it was `lib.mkForce true` in cli-modern.nix — to fully revert, remove the `./cli-modern.nix` import line too).

---

## Out-of-Scope Cleanups (do NOT do in this plan)

- Deleting `modules/upstream/home/zsh/p10k-config/` directory
- Removing Kitty from the home profile
- Cleaning up unused `lib` argument in `modules/upstream/home/zsh/default.nix`
- Mirroring changes to `meo-work` host
- Adjusting Hyprland window rules for Ghostty (already present in `modules/upstream/home/hyprland/windowrules.nix:32`)
