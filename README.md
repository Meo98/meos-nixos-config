# MeoNix

Personal NixOS configuration for two machines:

| Host | Hardware | Profile | Use |
|---|---|---|---|
| **meo** | ASUS Zephyrus G16 GU605 (Intel Meteor Lake + NVIDIA dGPU) | `nvidia-laptop` | Home / Trading Bot |
| **meo-work** | Lenovo ThinkPad (Intel i7-1165G7 + Iris Xe iGPU) | `intel` | Work |

Based on the excellent [ZaneyOS](https://gitlab.com/zaney/zaneyos) configuration — vendored in `modules/upstream/` as a snapshot, and augmented with custom modules in `modules/meo/`. See [`docs/MIGRATION.md`](docs/MIGRATION.md) for why this approach and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it's wired up.

## Installation auf einem neuen / frisch installierten Host

Voraussetzung: NixOS minimal-installation läuft schon, Flakes sind aktiviert (`nix.settings.experimental-features = [ "nix-command" "flakes" ];` in der bestehenden `/etc/nixos/configuration.nix`).

```bash
# 1. Repo nach ~/nixos-config klonen (Pfad ist HARDCODED in modules/upstream/core/nh.nix — nicht umbenennen)
git clone https://github.com/Meo98/meos-nixos-config.git ~/nixos-config

# 2. Bei NEUEM Host: hosts/<HOSTNAME>/ anlegen oder bestehendes meo/meo-work nutzen.
#    Hostname checken: hostnamectl status | grep "Static hostname"

# 3. Initial-Switch — WICHTIG: expliziten Flake-Pfad mitgeben.
#    Ohne den Pfad nutzt nh seinen NH_FLAKE default (von der alten/installierten Config),
#    was den Switch ins Leere laufen lässt. Klassische Henne-Ei-Falle.
sudo nh os switch --hostname <HOSTNAME> ~/nixos-config
# oder gleichwertig:  NH_FLAKE=$HOME/nixos-config nh os switch --hostname <HOSTNAME>

# 4. Komplett ausloggen aus dem grafischen Session und neu einloggen.
#    Grund: NH_FLAKE wird in /etc/profile.d/hm-session-vars.sh am LOGIN gesetzt,
#    nicht beim Shell-Start. `exec zsh` reicht nicht. Reboot tut's auch.

# 5. Verify:
echo $NH_FLAKE     # → /home/<user>/nixos-config
fr                 # smoke test, sollte in <10s clean durchlaufen
```

Falls Schritt 3 fehlschlägt mit `getting status of '/home/.../zaneyos'`: siehe [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) Sektion 3.

## Quickstart

```bash
# Rebuild current host (auto-detects via hostname, syncs to GitHub):
fr

# Update flake inputs + rebuild:
fu

# What is fr? Defined in modules/upstream/home/zsh/default.nix:
#   fr = "_zsync && nh os switch --hostname ${nixosTarget}"
#   _zsync = git pull && git commit -am "auto-sync from $(hostname) $(date)" && git push
```

The `_zsync` function in zsh auto-commits and pushes changes to GitHub when you run `fr` — so both hosts stay in sync automatically.

## Repository layout

```
nixos-config/                        # ~/nixos-config (renamed from ~/zaneyos)
├── flake.nix                        # description + 2 hosts (meo, meo-work)
├── flake.lock
├── README.md                        # ← you are here
├── CLAUDE.md                        # context for AI assistants (Claude Code)
├── docs/
│   ├── MIGRATION.md                 # why we forked, what we changed (2026-05-18)
│   ├── ARCHITECTURE.md              # how modules wire up
│   └── SYNC_UPSTREAM.md             # how to pull updates from zaneyos
├── hosts/
│   ├── meo/                         # home laptop (NVIDIA)
│   │   ├── default.nix              # NixOS config
│   │   ├── hardware-configuration.nix
│   │   ├── hardware.nix
│   │   ├── host-packages.nix        # bambu overlay imported here
│   │   ├── kanata.nix               # keyboard remapping
│   │   ├── variables.nix            # host-specific settings
│   │   └── affinity.nix             # Affinity v3 (Canva) via wine
│   └── meo-work/                    # work laptop (Intel)
│       └── ... (same structure, imports ../meo/affinity.nix shared)
├── modules/
│   ├── meo/                         # ✏️  ALL OUR CUSTOM CODE LIVES HERE
│   │   ├── default.nix              # imports trading-bot + hyprland + scripts
│   │   ├── bambu.nix                # Bambu Studio AppImage overlay
│   │   ├── trading-bot.nix          # systemd user service for Matrix Quant
│   │   ├── hyprland.nix             # imports custom hyprland helpers
│   │   ├── hyprland/                # custom hyprland helpers
│   │   │   ├── vol-smart.nix        # smart volume keys
│   │   │   ├── bright-smart.nix     # smart brightness keys
│   │   │   └── pyprland.nix         # pyprland scratchpads
│   │   ├── scripts.nix              # adds custom scripts to home.packages
│   │   └── scripts/
│   │       ├── bt-audio-monitor.nix # bluetooth audio routing watcher
│   │       ├── bt-audio-switch.nix  # quick switch BT outputs
│   │       ├── setup-secrets.nix    # bootstraps secrets from Bitwarden
│   │       └── travel-mode.nix      # CPU/GPU power down for battery
│   └── upstream/                    # 🔒 VENDORED FROM ZANEYOS (frozen snapshot)
│       ├── core/                    # system-level NixOS modules
│       ├── drivers/                 # GPU drivers (amd/intel/nvidia)
│       ├── home/                    # home-manager modules
│       ├── profiles/                # active: nvidia-laptop + intel
│       └── src/                     # zaneyos's helper scripts
├── cheatsheets/                     # vendored cheatsheets (used by qs-cheatsheets)
└── wallpapers/                      # used by hyprland config (path-relative)
```

## How to add custom code

**Custom module / config / script:** add to `modules/meo/`. Wire it up via `modules/meo/default.nix`.

**Modification to upstream module:** edit in-place in `modules/upstream/`. Mark the change with a comment like `# MODIFIED: ...` so future syncs are visible. See [`docs/SYNC_UPSTREAM.md`](docs/SYNC_UPSTREAM.md) for the periodic sync workflow.

**Bambu overlay:** lives in `modules/meo/bambu.nix` (not modules/), imported from both `hosts/*/host-packages.nix` via `(import ../../modules/meo/bambu.nix)`.

## Hosts setup for first-time / fresh install

After fresh `nixos-install`:
```bash
git clone https://github.com/Meo98/meos-nixos-config.git ~/nixos-config
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#<meo|meo-work>
```

For host secrets (Kraken keys, etc.) used by Matrix Quant bot — see `setup-secrets` script. Bitwarden CLI handles the bootstrap.

## Background

This config started as a fork of [`zaney/zaneyos`](https://gitlab.com/zaney/zaneyos) and accumulated 123 custom commits over time. On 2026-05-18 it was reorganized into "Clean Fork" structure — see [`docs/MIGRATION.md`](docs/MIGRATION.md) for the why and how.

License: Original zaneyos code is MIT (see commit history). Custom modules in `modules/meo/` are personal — no warranty, no support. Use at your own risk if you fork.
