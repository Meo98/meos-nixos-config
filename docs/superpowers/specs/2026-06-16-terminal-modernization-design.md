# Terminal Modernization — Design

**Date:** 2026-06-16
**Scope:** Personal terminal stack on `meo` host (NixOS + Hyprland + Home-Manager)
**Status:** Approved, pending implementation plan

## Problem

The current terminal stack (Kitty 0.44 + Zsh + Powerlevel10k) works but has rough edges:

- **Powerlevel10k** is functional but barely maintained anymore; the cross-shell ecosystem has shifted to Starship.
- **Kitty** is fine, but Ghostty offers a more polished default look (GPU-accelerated shaders, native Wayland, cleaner config model) and a Ghostty module already sits unused in this repo (`modules/upstream/home/terminals/ghostty.nix`).
- **Plain coreutils** for `ls`/`cat`/`cd`/history miss modern conveniences (Git status per file, syntax highlighting, frecency navigation, fuzzy history).

The goal is a coherent modernization that leans on infrastructure already present in the repo, not a from-scratch rebuild.

## Goals

1. Switch the default terminal emulator from Kitty to Ghostty without removing Kitty (safety net).
2. Replace Powerlevel10k with Starship for the Zsh prompt.
3. Add four modern CLI replacements: `eza`, `bat`, `zoxide`, `atuin`.
4. Preserve the existing Catppuccin Mocha aesthetic and Maple Mono NF font.
5. Touch as few files as possible — reuse existing upstream modules where they exist.

## Non-Goals

- Not changing Neovim, Yazi, Hyprland, or any other unrelated subsystem.
- Not removing Kitty (kept as fallback).
- Not enabling atuin cloud sync (local-only).
- Not changing the color theme or font.
- Not changing the Hyprland keybinding scheme — only the `$terminal` variable resolves to a new binary.

## Architecture

### Current state (verified)

| Concern | Where |
|---|---|
| Default terminal flag | `hosts/meo/variables.nix:71` — `terminal = "kitty"` |
| Ghostty enable flag | `hosts/meo/variables.nix` — `ghosttyEnable = false` |
| Kitty config | `modules/upstream/home/terminals/kitty.nix` (active) |
| Ghostty config | `modules/upstream/home/terminals/ghostty.nix` (full config, Catppuccin Mocha, cursor-warp shader, `alt+s` leader keybinds — currently dormant) |
| Zsh + p10k | `modules/upstream/home/zsh/default.nix` |
| Starship module | `modules/upstream/home/starship.nix` (exists, NOT imported by upstream `default.nix`) |
| eza module | `modules/upstream/home/eza.nix` — **already imported** (line 34 of upstream `default.nix`); `ls`/`ll` aliases likely already active |
| bat module | `modules/upstream/home/cli/bat.nix` — **already imported** (line 29 of upstream `default.nix`) |
| zoxide / atuin | Not in repo — need new config in `cli-modern.nix` |

### Target state

```
hosts/meo/variables.nix
  ├── terminal = "ghostty"        (was: "kitty")
  └── ghosttyEnable = true        (was: false)

modules/upstream/home/zsh/default.nix
  └── Remove p10k plugins block; rely on programs.starship instead

modules/meo/default.nix
  └── Import new modules/meo/cli-modern.nix

modules/meo/cli-modern.nix         (NEW)
  ├── programs.starship.enable  = true   (Catppuccin preset)
  ├── programs.eza.enable       = true
  ├── programs.bat              (Catppuccin Mocha theme)
  ├── programs.zoxide.enable    = true   (+ enableZshIntegration)
  └── programs.atuin.enable     = true   (+ enableZshIntegration, auto_sync = false)
```

Kitty config file stays in place (still imported by upstream `default.nix`). Switching the default merely changes which binary Hyprland launches via `$terminal`.

## Components

### 1. Variables flip (`hosts/meo/variables.nix`)

Two single-line changes. Hyprland reads `terminal` to build its `$mainMod, RETURN, exec, $terminal` binding; Home-Manager reads `ghosttyEnable` to conditionally import the Ghostty module.

### 2. Zsh prompt swap (`modules/upstream/home/zsh/default.nix`)

Remove the `plugins` entries for `powerlevel10k` and `powerlevel10k-config`. The `~/.config/zsh/p10k.zsh` file becomes orphaned but harmless. Starship init is handled by its own Home-Manager module — no manual `eval` needed.

### 3. New module — `modules/meo/cli-modern.nix`

A single small module covering the two things not already enabled upstream:

- **Starship**: import `modules/upstream/home/starship.nix` (it already has a config). If its preset is not Catppuccin Mocha, override `programs.starship.settings` in `cli-modern.nix` to load the Catppuccin Mocha preset.
- **zoxide**: `programs.zoxide.enable = true` + `enableZshIntegration = true`
- **atuin**: `programs.atuin.enable = true` + `enableZshIntegration = true` + `settings.auto_sync = false` + `settings.update_check = false`

`eza` and `bat` are already enabled by upstream imports — no work needed unless we want to override the bat theme to Catppuccin Mocha (decide during implementation by reading `cli/bat.nix`).

### 4. Hyprland integration

No change required. Hyprland already binds to `$terminal` which is set from `variables.nix`. Switching to `"ghostty"` flips the binding automatically.

## Data Flow

```
User Mod+Return
   └─> Hyprland reads $terminal = "ghostty"
        └─> spawns `ghostty`
             └─> Ghostty loads ~/.config/ghostty/config (generated by Home-Manager from ghostty.nix)
                  ├── theme = catppuccin-mocha
                  ├── shader = cursor_warp.glsl
                  └── starts zsh
                       ├── starship init (prompt)
                       ├── zoxide init (z command)
                       ├── atuin init (Ctrl+R binding)
                       └── aliases: ls -> eza, cat -> bat (via programs modules)
```

## Error Handling / Rollback

- **Ghostty fails to launch**: Kitty is still installed and on `$PATH`. Run `kitty` manually, then revert `terminal = "kitty"` in `variables.nix` and `nh os switch`.
- **Starship config breaks**: Zsh still loads; you get a default prompt. Revert by re-adding the p10k plugin block.
- **atuin Ctrl+R unfamiliar**: `bindkey '^R' history-incremental-search-backward` in `initContent` reverts to the old behavior without disabling atuin entirely.
- **Build fails**: NixOS generation rollback (`nh os rollback` or `nixos-rebuild --rollback`).

## Testing

After `fr` (rebuild + switch):

1. `which ghostty && ghostty --version` — verify binary present
2. Hyprland: Mod+Return — should open Ghostty (not Kitty)
3. New shell: prompt should be Starship (not P10k box-drawing)
4. `ls` — expect eza output with icons
5. `cat ~/nixos-config/flake.nix` — expect bat with syntax highlighting
6. `z nixos` (after one visit to `~/nixos-config`) — expect cd to the directory
7. Ctrl+R — expect atuin fzf-style picker
8. `kitty` from a shell — verify fallback still works

## Open Questions Resolved During Brainstorm

- **Keep Kitty installed?** Yes — costs nothing, valuable safety net.
- **atuin cloud sync?** No — local-only.
- **Replace zsh entirely (fish/nushell)?** Not in scope. Stay on zsh.
- **Change font?** No, Maple Mono NF stays.

## File Touch List

| File | Action |
|---|---|
| `hosts/meo/variables.nix` | Edit: 2 lines |
| `modules/upstream/home/zsh/default.nix` | Edit: remove p10k plugin block (~6 lines) |
| `modules/meo/cli-modern.nix` | Create |
| `modules/meo/default.nix` | Edit: add 1 import line |
| `docs/superpowers/specs/2026-06-16-terminal-modernization-design.md` | This file |

Estimated diff: ~50 lines net additions, ~6 lines deletions.
