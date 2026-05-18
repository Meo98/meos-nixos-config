# Architecture

How this NixOS configuration is wired together end-to-end.

## Entry point: `flake.nix`

```nix
nixosConfigurations = {
  meo      = mkNixosConfig { profile = "nvidia-laptop"; nixosTarget = "meo"; };
  meo-work = mkNixosConfig { host = "meo-work"; profile = "intel"; nixosTarget = "meo-work"; };
};
```

`mkNixosConfig` is a helper that wires up four module imports:
1. `./hosts/${host}` — host-specific NixOS config (hardware, hostname, user services)
2. `./modules/upstream/core/overlays.nix` — global overlays (antigravity, awww, affinity-nix)
3. `./modules/upstream/profiles/${profile}` — driver profile (which selects more modules)
4. `nix-flatpak.nixosModules.nix-flatpak`

Plus `specialArgs = { inherit inputs username host profile nixosTarget; }`.

## Module dependency chain

```
flake.nix
    │
    ▼
./hosts/${host}/default.nix    (e.g., hosts/meo/default.nix)
    │
    ├── ./hardware.nix
    ├── ./host-packages.nix    (imports ../../modules/meo/bambu.nix as overlay)
    ├── ./kanata.nix
    ├── ./affinity.nix
    └── home-manager.users.${username}.imports = [ ../../modules/meo ]
                                                       │
                                                       ▼
                                          modules/meo/default.nix
                                          (imports: trading-bot.nix, hyprland.nix, scripts.nix)
                                                       │
                                            (added to HM context)

./modules/upstream/profiles/${profile}/default.nix
    │
    ├── imports ../../../../hosts/${host}        (already imported above, no-op due to module deduplication)
    ├── imports ../../drivers                    (modules/upstream/drivers — amd/intel/nvidia)
    └── imports ../../core                       (modules/upstream/core — all system modules)
                                       │
                                       ▼
                            modules/upstream/core/default.nix
                                       │
                                       ├── imports ./boot.nix
                                       ├── imports ./network.nix
                                       ├── imports ./user.nix        ← sets up home-manager
                                       │       │
                                       │       └── home-manager.users.${username}.imports = [./../home]
                                       │                                          │
                                       │                                          ▼
                                       │                          modules/upstream/home/default.nix
                                       │                          (imports many upstream HM modules)
                                       └── ... (all the other system modules)
```

## Two separate home-manager import chains

The home-manager imports come from **two places** that merge:

1. **`modules/upstream/core/user.nix`** sets:
   ```nix
   home-manager.users.${username}.imports = [./../home];   # modules/upstream/home/
   ```

2. **`hosts/{meo,meo-work}/default.nix`** adds:
   ```nix
   home-manager.users.${username}.imports = [ ../../modules/meo ];
   ```

NixOS module system merges these into a combined list, so the user's HM config = upstream's HM stuff + our custom stuff.

## Overlays

Overlays are wired in `modules/upstream/core/overlays.nix`:
- `inputs.antigravity-nix.overlays.default` — `pkgs.google-antigravity`
- `(final: prev: { awww = inputs.awww.packages.${prev.system}.default; })` — `pkgs.awww`
- `inputs.affinity-nix.overlays.default` — `pkgs.affinity-v3`, `pkgs.affinity-{photo,designer,publisher}`

Plus per-host overlays in `hosts/{meo,meo-work}/host-packages.nix`:
- `(import ../../modules/meo/bambu.nix)` — `pkgs.bambu-studio`

## File-relative paths

zaneyos's modules pervasively use the pattern:
```nix
{ host, ... }: let
  vars = import ../../../../hosts/${host}/variables.nix;
in { ... }
```

This is **file-relative**, not `inputs.self`-relative or path-arg-based. The `../` count depends on the file's depth within `modules/upstream/`. After our migration that added one level of nesting (`modules/X/` → `modules/upstream/X/`), all these paths were shifted by `+1 ../`.

| File location | Path to hosts/ |
|---|---|
| `modules/upstream/core/default.nix` | `../../../hosts/${host}/variables.nix` (3 up) |
| `modules/upstream/home/hyprland/binds.nix` | `../../../../hosts/${host}/variables.nix` (4 up) |
| `modules/upstream/profiles/nvidia-laptop/default.nix` | `../../../../hosts/${host}/variables.nix` (4 up) |

**Implication when adding zaneyos modules from upstream:** if you copy a new file from zaneyos to `modules/upstream/`, you must add **+1** `../` to all path-relative imports before it'll work. Or restructure to receive `vars` as a function argument.

## `hosts/{host}/variables.nix` pattern

Each host has a `variables.nix` with the same schema (mostly inherited from zaneyos). Some keys are read by upstream modules directly:
- `gitUsername`, `displayName`, `gitEmail` — used by `modules/upstream/core/user.nix`, `modules/upstream/home/cli/git.nix`
- `enableNFS`, `enableAffinity`, `printEnable` — feature toggles
- `keyboardLayout`, `consoleKeyMap` — used by various modules
- `intelID`, `amdgpuID`, `nvidiaID` — used by `modules/upstream/profiles/*` for PRIME setup
- `waybarChoice`, `animChoice` — path to choice modules (e.g., `../../modules/upstream/home/waybar/waybar-ddubs.nix`)
- `stylixImage` — path to wallpaper image
- `mimeDefaultApps` — xdg defaults
- `hostId` — needed for ZFS

When making changes, prefer host-specific via `variables.nix` over editing `modules/upstream/` directly.

## Inputs and where they're used

| Input | Where used |
|---|---|
| `nixpkgs` (unstable) | All over — base packages |
| `home-manager` | `modules/upstream/core/user.nix` |
| `stylix` | `modules/upstream/core/default.nix` (theme) |
| `nix-flatpak` | `flake.nix` outputs (flatpak NixOS module) |
| `nvf`, `nixvim` | `modules/upstream/home/editors/nixvim.nix` |
| `noctalia`, `quickshell` | `modules/upstream/core/quickshell.nix`, `modules/upstream/home/noctalia.nix` |
| `antigravity-nix` | `modules/upstream/core/overlays.nix` |
| `awww` | `modules/upstream/core/overlays.nix` (replaces deprecated swww) |
| `zen-browser` | (referenced when enabled) |
| `affinity-nix` | `modules/upstream/core/overlays.nix` |
| `alejandra` | `flake.nix` formatter |
| `sddm-noctalia` | `modules/upstream/core/sddm.nix` (theme) |

## What lives outside this repo

- **Wallpapers:** in `wallpapers/` — referenced via `../../../../wallpapers` from `modules/upstream/home/hyprland/hyprland.nix`. Path-relative; if you move this dir, that file breaks.
- **Trading bot binary:** `/home/meo/quant-trading-bot/rust/target/release/matrix_quant_core` — hardcoded path in `modules/meo/trading-bot.nix`.
- **Affinity user data:** `~/.local/share/affinity-v3/` — managed by `pkgs.affinity-v3` runtime.
- **Bitwarden vault:** consumed by `setup-secrets.sh` for Kraken API keys etc.
