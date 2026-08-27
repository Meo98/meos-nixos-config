# niri-Migration (Host `meo`) — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** niri als Standard-Session auf Host `meo` einrichten, mit Hyprland als
weiterhin wählbarem Rückweg in SDDM.

**Architecture:** Zweiklang wie bei Hyprland — `programs.niri` (NixOS, aus
nixpkgs) für Session/Portals/systemd-Units, `wayland.windowManager.niri`
(Home-Manager, aus dem bestehenden HM-Pin) für die Konfiguration. Die HM-Option
`settings` ist ein Nix-Attrset, das über `lib.hm.generators.toKDL` nach
`~/.config/niri/config.kdl` übersetzt und in der `checkPhase` durch
`niri validate` geprüft wird. Kein neuer Flake-Input.

**Tech Stack:** NixOS unstable, Home-Manager (Pin `ec1a8fdf`), niri 26.04,
xwayland-satellite 0.8.2, Noctalia v5.0.0-beta.3, Stylix, SDDM.

**Spec:** `docs/superpowers/specs/2026-08-27-niri-migration-design.md`

## Global Constraints

- Host-Scope: **nur `meo`**. `meo-work` darf keine Verhaltensänderung bekommen.
  Jeder NixOS-seitige Schalter gehört nach `hosts/meo/default.nix`, niemals nach
  `modules/upstream/core/`.
- `modules/upstream/` wird in diesem Plan **nicht angefasst**. Alle neuen
  Dateien liegen unter `modules/meo/` (Regel aus `CLAUDE.md`).
- Vor jedem Commit müssen **beide** Hosts bauen:
  `nh os build --hostname meo` und `nh os build --hostname meo-work`
  (Anti-Pattern-Regel aus `CLAUDE.md`).
- `fr` committet und pusht automatisch jede dirty Datei im Repo. Es gibt keine
  Scratch-Zone. Beim Start dieses Plans steht `hosts/meo/host-packages.nix`
  bereits dirty — das ist Vorzustand, nicht Teil dieses Plans.
- Der Wechsel der Default-Session passiert **ausschließlich in Task 11**, ganz
  am Ende. Bis dahin bleibt Hyprland Default und niri ist nur ein zusätzlicher,
  manuell wählbarer Eintrag. Diese Reihenfolge ist die Sicherheitsleine.
- niri-Bind-Properties sind ausschließlich `repeat`, `allow-when-locked`,
  `cooldown-ms`, `hotkey-overlay-title`, `allow-inhibiting`. `on-release`
  existiert **nicht**.
- Doppelte Binds lehnt `niri validate` mit `unexpected keybind` ab. Der Build
  bricht dann — das ist erwünscht, kein Fehler im Plan.

## Test-Schleife

Ein voller `nh os build` dauert Minuten. Für die Config selbst gibt es eine
schnelle Schleife, die genau die `checkPhase` mit `niri validate` auslöst:

```bash
cd ~/nixos-config
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source'
```

Erfolg = Pfad im Store. Fehler = `niri validate`-Meldung mit Zeilennummer.
Den erzeugten KDL-Inhalt ansehen:

```bash
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')"
```

Dieses Kommando ist verifiziert (die Anführungszeichen im Attributpfad
funktionieren in `nix build`). Es ersetzt **nicht** den vollen Build vor dem
Commit, sondern verkürzt nur die Iteration innerhalb einer Task.

## toKDL-Konventionen

Der Generator ist verifiziert; diese vier Formen decken alles ab, was der Plan
braucht:

| Nix | erzeugtes KDL |
|---|---|
| `prefer-no-csd = {}` | `prefer-no-csd` (Leaf-Node ohne Argument) |
| `layout.gaps = 8` | `layout { gaps 8 }` |
| `position._props = { x = 0; y = 0; }` | `position x=0 y=0` |
| `output._args = [ "eDP-1" ]` | `output "eDP-1" { … }` |
| `_children = [ … ]` | wiederholte Top-Level-Nodes in Listenreihenfolge |

Wichtig: Attrset-Schlüssel werden **alphabetisch** ausgegeben, `_children`
behält die Listenreihenfolge. Deshalb müssen alle `window-rule`-Blöcke in
**einer** Datei stehen — bei niri gewinnt die zuletzt passende Regel, und über
Modulgrenzen hinweg ist die Reihenfolge nicht vorhersagbar. `output`-Blöcke
sind reihenfolgeunabhängig und dürfen getrennt liegen.

`settings._children` aus mehreren Modulen wird korrekt konkateniert (verifiziert
per `lib.evalModules`), verschachtelte Attrsets mergen normal.

## File Structure

```
modules/meo/niri/
├── default.nix      Modul-Aggregator: enable, package, xwayland-satellite,
│                    globale Einzelwerte (prefer-no-csd, screenshot-path)
├── env.nix          settings.environment
├── input.nix        settings.input (Tastatur, Touchpad, Maus)
├── outputs.nix      settings._children → output-Blöcke
├── layout.nix       settings.layout, overview, animations
├── binds-nav.nix    settings.binds → Navigation, Fenster bewegen, Layout
├── binds-apps.nix   settings.binds → Apps, Noctalia, Screenshots, Media
├── rules.nix        settings._children → workspace + alle window-rule-Blöcke
└── startup.nix      settings.spawn-at-startup / spawn-sh-at-startup

modules/meo/scripts/
├── keymap-popup.nix      Toggle für die Keyball-Overlays (F13–F15)
└── niri-term-toggle.nix  Ersatz für den pyprland-Scratchpad

modules/meo/niri-gpu-smart.nix   NixOS-Modul: Session "niri (Smart GPU)"

geändert:
modules/meo/default.nix          + ./niri
modules/meo/scripts.nix          + die zwei neuen Scripts
hosts/meo/default.nix            + programs.niri.enable, + niri-gpu-smart
                                 ~ edp-refresh-switcher compositor-aware
                                 + defaultSession (erst Task 11)
```

---

### Task 1: Gerüst — niri baut, ohne die Session anzufassen

Nach dieser Task existiert eine gültige, minimale niri-Config und ein
zusätzlicher SDDM-Eintrag. Hyprland bleibt Default.

**Files:**
- Create: `modules/meo/niri/default.nix`
- Modify: `modules/meo/default.nix` (imports-Liste)
- Modify: `hosts/meo/default.nix` (imports-Liste unverändert; neuer Options-Block)

**Interfaces:**
- Consumes: nichts.
- Produces: die Option `wayland.windowManager.niri.settings`, in die alle
  folgenden Tasks hineinschreiben. Der Store-Pfad der generierten Datei ist
  über `…xdg.configFile."niri/config.kdl".source` erreichbar.

- [ ] **Step 1: `modules/meo/niri/default.nix` anlegen**

```nix
# niri — scrollable-tiling Wayland compositor.
# Spec: docs/superpowers/specs/2026-08-27-niri-migration-design.md
#
# Home-Manager-Modul. Die System-Seite (programs.niri.enable und
# services.displayManager.defaultSession) liegt bewusst in hosts/meo/default.nix,
# damit meo-work diesen Code zwar im Repo hat, aber nie in seiner Session.
#
# Die Unterdateien schreiben alle in wayland.windowManager.niri.settings; das
# Modulsystem merged Attrsets und konkateniert _children-Listen.
{pkgs, ...}: {
  imports = [
    # weitere Dateien werden in den folgenden Tasks ergaenzt
  ];

  wayland.windowManager.niri = {
    enable = true;
    package = pkgs.niri;
    systemd.enable = true;
    xwaylandSatellitePackage = pkgs.xwayland-satellite;

    # checkConfig ist per Default an (weil package != null) und laesst die
    # generierte KDL in der checkPhase durch `niri validate` laufen. Ein
    # Config-Fehler bricht damit den Build, nicht die Session.
    settings = {
      # Client-Side-Decorations abschalten, wo die App mitspielt.
      prefer-no-csd = {};

      # Gleiche Ablage wie die bisherigen hyprshot-Binds.
      screenshot-path = "~/Pictures/ScreenShots/%Y-%m-%d %H-%M-%S.png";

      # Die Tastenuebersicht nicht bei jedem Login einblenden; sie liegt auf Mod+F1.
      hotkey-overlay.skip-at-startup = {};
    };
  };
}
```

- [ ] **Step 2: `modules/meo/default.nix` um den Import ergänzen**

Die `imports`-Liste erhält `./niri` direkt nach `./hyprland.nix`:

```nix
    ./hyprland.nix
    ./niri
    ./scripts.nix
```

- [ ] **Step 3: `hosts/meo/default.nix` — System-Seite aktivieren**

Direkt nach `programs.kdeconnect.enable = true;` einfügen:

```nix
  # --- niri (Migration 2026-08-27) ---
  # Spec: docs/superpowers/specs/2026-08-27-niri-migration-design.md
  # Bewusst host-lokal statt in modules/upstream/core/packages.nix, damit
  # meo-work den niri-Code zwar im Repo hat, aber nie in seiner Session.
  # Das nixpkgs-Modul liefert Session-Datei, systemd-Units, xdg-Portals
  # (gnome + gtk) und gnome-keyring. Es setzt defaultSession selbst per
  # mkDefault "niri" — deshalb bleibt Hyprland bis Task 11 explizit Default.
  programs.niri.enable = true;

  # defaultSession ist im Ist-Zustand null (verifiziert per nix eval); SDDM
  # merkt sich die letzte Wahl, und das ist hier "hyprland-smart"
  # (DESKTOP_SESSION der laufenden Sitzung). Das niri-Modul setzt defaultSession
  # selbst per mkDefault "niri" — ohne Gegenwehr waere die Session ab diesem
  # Commit gewechselt. mkForce haelt sie bis Task 11 auf Hyprland.
  services.displayManager.defaultSession = lib.mkForce "hyprland-smart";
```

`lib` steht in `hosts/meo/default.nix` bereits in den Modulargumenten
(`{ config, pkgs, inputs, lib, username, ... }`), es ist kein Import nötig.

- [ ] **Step 4: Config-Generierung prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')"
```
Expected: KDL mit `prefer-no-csd`, `screenshot-path "…"` und
`hotkey-overlay { skip-at-startup }`. Kein Fehler von `niri validate`.

- [ ] **Step 5: Beide Hosts bauen**

Run:
```bash
nh os build --hostname meo && nh os build --hostname meo-work
```
Expected: beide erfolgreich.

- [ ] **Step 6: Sitzungsliste prüfen**

Run:
```bash
ls "$(nix build --no-link --print-out-paths '.#nixosConfigurations.meo.config.system.build.toplevel')/sw/share/wayland-sessions/" 2>/dev/null \
  || nix eval '.#nixosConfigurations.meo.config.services.displayManager.sessionPackages' --apply 'map (p: p.name)'
```
Expected: niri taucht neben Hyprland auf. `defaultSession` ist `hyprland`.

- [ ] **Step 7: Commit**

```bash
cd ~/nixos-config
git add modules/meo/niri/default.nix modules/meo/default.nix hosts/meo/default.nix
git commit -m "feat(niri): Geruest — HM-Modul + System-Enable, Hyprland bleibt Default"
```

---

### Task 2: Session-Umgebung und Eingabegeräte

**Files:**
- Create: `modules/meo/niri/env.nix`
- Create: `modules/meo/niri/input.nix`
- Modify: `modules/meo/niri/default.nix` (imports)

**Interfaces:**
- Consumes: `wayland.windowManager.niri.settings` aus Task 1.
- Produces: `settings.environment`, `settings.input`, `settings.xwayland-satellite`.
  Keine Namen, auf die spätere Tasks zugreifen.

- [ ] **Step 1: `modules/meo/niri/env.nix` anlegen**

```nix
# Session-Umgebung. Portiert aus modules/upstream/home/hyprland/env.nix,
# aber bewusst reduziert:
#   - XDG_CURRENT_DESKTOP / XDG_SESSION_DESKTOP setzt niri selbst auf "niri";
#     die Hyprland-Werte wuerden Apps in die Irre fuehren.
#   - GDK_SCALE / QT_SCALE_FACTOR entfallen: niri liefert per-Output-Fractional-
#     Scaling ueber wp-fractional-scale, globale Skalenfaktoren wuerden das
#     doppelt anwenden.
#   - NIXPKGS_ALLOW_UNFREE gehoert nicht in eine Session-Umgebung.
{pkgs, ...}: {
  wayland.windowManager.niri.settings = {
    environment = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      CLUTTER_BACKEND = "wayland";
      GDK_BACKEND = "wayland,x11";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "x11";

      # Wie in env.nix: Kinder der Session erben diese Werte, sonst greift
      # noch das alte EDITOR aus dem Profil.
      EDITOR = "nvim";
      TERMINAL = "ghostty";
      XDG_TERMINAL_EMULATOR = "ghostty";
    };

    # XWayland laeuft in niri als eigener Prozess. Das HM-Modul installiert das
    # Paket ueber xwaylandSatellitePackage; hier wird nur der Pfad verdrahtet,
    # damit niri es bei Bedarf selbst startet.
    xwayland-satellite.path = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
  };
}
```

- [ ] **Step 2: `modules/meo/niri/input.nix` anlegen**

```nix
# Eingabegeraete. keyboardLayout kommt aus hosts/<host>/variables.nix, damit
# der Wert nicht doppelt gepflegt wird (dort steht "ch").
{host, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
  inherit (vars) keyboardLayout;
in {
  wayland.windowManager.niri.settings.input = {
    keyboard = {
      xkb.layout = keyboardLayout;
      repeat-delay = 400;
      repeat-rate = 40;
    };

    touchpad = {
      tap = {};
      natural-scroll = {};
      dwt = {}; # disable-while-typing
      accel-profile = "adaptive";
    };

    mouse.accel-profile = "flat";

    # Entspricht dem bisherigen focus_follows_mouse. max-scroll-amount="0%"
    # heisst: Fokus folgt der Maus, aber das Band scrollt dabei nicht mit —
    # sonst wandert der Viewport beim blossen Ueberfahren.
    focus-follows-mouse._props.max-scroll-amount = "0%";

    # Zeiger springt zum neu fokussierten Fenster. Auf zwei Monitoren mit
    # unterschiedlicher Skalierung spart das viel Sucherei.
    warp-mouse-to-focus = {};
  };
}
```

- [ ] **Step 3: Imports in `modules/meo/niri/default.nix` ergänzen**

```nix
  imports = [
    ./env.nix
    ./input.nix
  ];
```

- [ ] **Step 4: Generierte KDL prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')"
```
Expected: Block `environment { … }` mit den elf Variablen, Block `input { … }`
mit `layout "ch"` unter `keyboard { xkb { … } }`, und
`xwayland-satellite { path "/nix/store/…-xwayland-satellite-0.8.2/bin/xwayland-satellite" }`.

- [ ] **Step 5: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 6: Commit**

```bash
git add modules/meo/niri/env.nix modules/meo/niri/input.nix modules/meo/niri/default.nix
git commit -m "feat(niri): Session-Umgebung, Eingabegeraete und xwayland-satellite"
```

---

### Task 3: Monitore

Das ist eine der beiden Achsen, wegen denen migriert wird. Die Werte stammen 1:1
aus `extraMonitorSettings` in `hosts/meo/variables.nix`; niri rechnet Positionen
in logischen Koordinaten (2560 / 1.6 = 1600), daher übertragen sie sich direkt.

**Files:**
- Create: `modules/meo/niri/outputs.nix`
- Modify: `modules/meo/niri/default.nix` (imports)

**Interfaces:**
- Consumes: `settings` aus Task 1.
- Produces: `settings._children` mit zwei `output`-Einträgen. Weitere Tasks
  dürfen `_children` ebenfalls setzen; die Listen werden konkateniert.

- [ ] **Step 1: `modules/meo/niri/outputs.nix` anlegen**

```nix
# Monitor-Konfiguration.
#
# Uebernommen aus hosts/meo/variables.nix extraMonitorSettings:
#   monitor = eDP-1,2560x1600@240,0x0,1.6
#   monitor = DP-1,preferred,1600x141,1.2
#
# niri rechnet Positionen in LOGISCHEN Koordinaten. 2560 / 1.6 = 1600, deshalb
# liegt DP-1 bei x=1600 — dieselbe Zahl wie in der Hyprland-Zeile.
#
# DP-1 bekommt bewusst kein mode: ohne Angabe waehlt niri den bevorzugten Modus
# ("preferred" in der Hyprland-Notation).
#
# Reihenfolge der output-Bloecke ist bedeutungslos, deshalb duerfen sie in einer
# eigenen Datei liegen (anders als window-rule, siehe rules.nix).
{...}: {
  wayland.windowManager.niri.settings._children = [
    {
      output = {
        _args = ["eDP-1"];
        mode = "2560x1600@240.000";
        scale = 1.6;
        position._props = {
          x = 0;
          y = 0;
        };
        # on-demand: VRR nur, wenn eine App es anfordert. Dauerhaftes VRR auf
        # dem OLED ist bei statischem Bild unnoetig.
        variable-refresh-rate._props.on-demand = true;
      };
    }
    {
      output = {
        _args = ["DP-1"];
        scale = 1.2;
        position._props = {
          x = 1600;
          y = 141;
        };
      };
    }
  ];
}
```

- [ ] **Step 2: Import ergänzen**

`./outputs.nix` in die `imports`-Liste von `modules/meo/niri/default.nix`.

- [ ] **Step 3: Generierte KDL prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" | grep -A6 '^output'
```
Expected:
```
output "eDP-1" {
	mode "2560x1600@240.000"
	position x=0 y=0
	scale 1.600000
	variable-refresh-rate on-demand=true
}
output "DP-1" {
	position x=1600 y=141
	scale 1.200000
}
```

- [ ] **Step 4: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 5: Commit**

```bash
git add modules/meo/niri/outputs.nix modules/meo/niri/default.nix
git commit -m "feat(niri): Monitor-Konfiguration eDP-1 1.6x und DP-1 1.2x"
```

---

### Task 4: Layout, Overview und Animationen

**Files:**
- Create: `modules/meo/niri/layout.nix`
- Modify: `modules/meo/niri/default.nix` (imports)

**Interfaces:**
- Consumes: `settings` aus Task 1; `config.lib.stylix.colors` aus dem
  bestehenden Stylix-Setup (verifiziert: `…withHashtag.base0D` liefert `#73d0ff`).
- Produces: `settings.layout`, `settings.overview`, `settings.animations`.

- [ ] **Step 1: `modules/meo/niri/layout.nix` anlegen**

```nix
# Spalten-Layout, Overview und Animationen.
#
# Die Fokusring-Farben spiegeln die bisherige Hyprland-Border
# (modules/upstream/home/hyprland/hyprland.nix:82-83): Gradient base08 -> base0C
# bei 45 Grad fuer aktiv, base01 fuer inaktiv. Damit bleibt der visuelle
# Wiedererkennungswert erhalten und die Farben folgen weiter Stylix.
{config, ...}: let
  c = config.lib.stylix.colors.withHashtag;
in {
  wayland.windowManager.niri.settings = {
    layout = {
      gaps = 8;

      # "never": die fokussierte Spalte wird nicht automatisch zentriert.
      # Beim Einstieg ins scrollable tiling ist ein stabiler Viewport leichter
      # zu lesen als einer, der bei jedem Fokuswechsel nachrueckt.
      # Wenn sich das nach ein paar Tagen falsch anfuehlt: "always" probieren.
      center-focused-column = "never";

      # Mod+R zykliert durch diese Breiten.
      preset-column-widths._children = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
      ];

      default-column-width.proportion = 0.5;

      focus-ring = {
        width = 2;
        active-gradient._props = {
          from = c.base08;
          to = c.base0C;
          angle = 45;
        };
        inactive-color = c.base01;
      };

      # Fokusring statt zusaetzlichem Rahmen — sonst hat jedes Fenster zwei.
      border.off = {};
    };

    # Mod+Tab. Ersetzt den quickshell-Overview-Daemon (qs -c overview), der
    # bisher per exec-once mitlief.
    overview.zoom = 0.5;

    animations.slowdown = 1.0;
  };
}
```

- [ ] **Step 2: Import ergänzen**

`./layout.nix` in die `imports`-Liste von `modules/meo/niri/default.nix`.

- [ ] **Step 3: Generierte KDL prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" | grep -A20 '^layout'
```
Expected: `focus-ring` enthält `active-gradient from="#…" to="#…" angle=45`
mit echten Hex-Werten (keine leeren Strings), `border { off }`,
`preset-column-widths` mit drei `proportion`-Zeilen.

- [ ] **Step 4: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 5: Commit**

```bash
git add modules/meo/niri/layout.nix modules/meo/niri/default.nix
git commit -m "feat(niri): Spalten-Layout, Overview und Stylix-Fokusring"
```

---

### Task 5: Helper-Scripts

Zwei Scripts, die Verhalten ersetzen, das niri nicht direkt kann. Sie müssen vor
den Binds existieren, die sie aufrufen.

**Files:**
- Create: `modules/meo/scripts/keymap-popup.nix`
- Create: `modules/meo/scripts/niri-term-toggle.nix`
- Modify: `modules/meo/scripts.nix` (home.packages)

**Interfaces:**
- Consumes: nichts.
- Produces: zwei Kommandos im `PATH`:
  - `keymap-popup <layer>` — `layer` ist `1`, `2` oder `3`. Kein Rückgabewert,
    Seiteneffekt ist ein `imv`-Fenster.
  - `niri-term-toggle` — keine Argumente.
  Beide werden in Task 7 (`binds-apps.nix`) per `spawn-sh` aufgerufen.

- [ ] **Step 1: `modules/meo/scripts/keymap-popup.nix` anlegen**

```nix
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "keymap-popup";
  runtimeInputs = with pkgs; [imv procps];
  text = ''
    # Keyball-Keymap-Overlays (F13/F14/F15).
    #
    # Unter Hyprland war das ein bind/bindr-Paar: druecken zeigt, loslassen
    # versteckt. niri 26.04 kennt KEINE Release-Bindings — gueltige
    # Bind-Properties sind nur repeat, allow-when-locked, cooldown-ms,
    # hotkey-overlay-title und allow-inhibiting. Deshalb hier ein Toggle:
    # erneuter Tastendruck schliesst das Bild wieder.
    #
    # Der Marker "niri-keymap-popup" steht nur in der imv-Kommandozeile, nicht
    # im Namen dieses Scripts — sonst wuerde pkill -f sich selbst treffen.
    layer="''${1:-1}"
    img="$HOME/Pictures/Screenshots/keymap_layer''${layer}.png"

    if pkill -f 'niri-keymap-popup' 2>/dev/null; then
      exit 0
    fi

    if [ ! -f "$img" ]; then
      echo "keymap-popup: $img existiert nicht" >&2
      exit 1
    fi

    exec imv -n niri-keymap-popup "$img"
  '';
}
```

- [ ] **Step 2: `modules/meo/scripts/niri-term-toggle.nix` anlegen**

```nix
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "niri-term-toggle";
  runtimeInputs = with pkgs; [niri jq];
  text = ''
    # Ersatz fuer den pyprland-Scratchpad (Mod+Shift+T).
    #
    # niri hat kein Scratchpad und pyprland ist Hyprland-only. Stattdessen ein
    # benannter Workspace "term" (deklariert in modules/meo/niri/rules.nix),
    # auf dem per spawn-at-startup ein Ghostty mit eigener app-id liegt.
    #
    # Ein einzelner Bind kann nicht bedingt zurueckspringen, daher entscheidet
    # dieses Script anhand des gerade fokussierten Workspace.
    focused=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .name // ""')

    if [ "$focused" = "term" ]; then
      niri msg action focus-workspace-previous
    else
      niri msg action focus-workspace term
    fi
  '';
}
```

- [ ] **Step 3: `modules/meo/scripts.nix` erweitern**

Die `home.packages`-Liste erhält zwei Einträge, eingefügt nach `hilfe.nix`:

```nix
    (import ./scripts/keymap-popup.nix      { inherit pkgs; })
    (import ./scripts/niri-term-toggle.nix  { inherit pkgs; })
```

- [ ] **Step 4: Scripts bauen und Shellcheck bestehen**

`writeShellApplication` lässt ShellCheck über den Text laufen; ein Syntax- oder
Quoting-Fehler bricht hier, nicht erst zur Laufzeit.

Run:
```bash
cd ~/nixos-config
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.home.path'
```
Expected: Store-Pfad, kein ShellCheck-Fehler.

- [ ] **Step 5: Scripts sind im Profil**

Run:
```bash
P=$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.home.path')
ls "$P/bin" | grep -E 'keymap-popup|niri-term-toggle'
```
Expected: beide Namen erscheinen.

- [ ] **Step 6: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich. (Die Scripts landen auch auf meo-work im Profil —
harmlos, sie werden dort von nichts aufgerufen.)

- [ ] **Step 7: Commit**

```bash
git add modules/meo/scripts/keymap-popup.nix modules/meo/scripts/niri-term-toggle.nix modules/meo/scripts.nix
git commit -m "feat(niri): Helper-Scripts keymap-popup (Toggle) und niri-term-toggle"
```

---

### Task 6: Binds — Navigation, Bewegen, Layout

**Files:**
- Create: `modules/meo/niri/binds-nav.nix`
- Modify: `modules/meo/niri/default.nix` (imports)

**Interfaces:**
- Consumes: `settings` aus Task 1.
- Produces: `settings.binds` mit den Navigations-Keys. Task 7 schreibt in
  dasselbe Attrset — die Schlüsselmengen dürfen sich **nicht** überschneiden,
  sonst bricht der Build mit einem Options-Konflikt (und niri zusätzlich mit
  `unexpected keybind`).

- [ ] **Step 1: `modules/meo/niri/binds-nav.nix` anlegen**

```nix
# Navigation, Fenster bewegen, Layout-Manipulation.
#
# Schema laut Spec Abschnitt 7 (Hybrid):
#   - h/l und Pfeil links/rechts wechseln die SPALTE (Achsenwechsel gegenueber
#     Hyprland, wo es Richtungsfokus war)
#   - j/k und Pfeil hoch/runter wechseln das Fenster INNERHALB der Spalte
#     (wie bisher)
#   - u/i wechseln den Workspace (neu; Workspaces sind in niri vertikal)
#
# Bewusst NICHT uebernommen (kein Gegenstueck im Spalten-Modell): pseudo,
# togglesplit, workspaceopt allfloat, swapwindow hoch/runter.
#
# Mod+Alt+H/L waere die konsequente VI-Variante fuer swap, kollidiert aber mit
# Mod+Alt+L (Lock and Suspend) in binds-apps.nix. Die bisherige Hyprland-Config
# loeste das ueber rohe Keycodes (43/46); die kennt niri nicht. Deshalb liegt
# swap ausschliesslich auf Mod+Alt+Pfeil.
{...}: let
  # Mod+<n> fokussiert Workspace n, Mod+Shift+<n> schiebt die Spalte dorthin.
  # Taste "0" steht wie bisher fuer Workspace 10.
  wsKeys = [
    {key = "1"; ws = 1;}
    {key = "2"; ws = 2;}
    {key = "3"; ws = 3;}
    {key = "4"; ws = 4;}
    {key = "5"; ws = 5;}
    {key = "6"; ws = 6;}
    {key = "7"; ws = 7;}
    {key = "8"; ws = 8;}
    {key = "9"; ws = 9;}
    {key = "0"; ws = 10;}
  ];

  focusBinds = builtins.listToAttrs (map (e: {
      name = "Mod+${e.key}";
      value.focus-workspace = e.ws;
    })
    wsKeys);

  moveBinds = builtins.listToAttrs (map (e: {
      name = "Mod+Shift+${e.key}";
      value.move-column-to-workspace = e.ws;
    })
    wsKeys);
in {
  wayland.windowManager.niri.settings.binds =
    focusBinds
    // moveBinds
    // {
      # ---- Fokus: Spalten ----
      "Mod+H".focus-column-left = {};
      "Mod+L".focus-column-right = {};
      "Mod+Left".focus-column-left = {};
      "Mod+Right".focus-column-right = {};

      # ---- Fokus: Fenster in der Spalte ----
      "Mod+J".focus-window-down = {};
      "Mod+K".focus-window-up = {};
      "Mod+Down".focus-window-down = {};
      "Mod+Up".focus-window-up = {};

      # ---- Fokus: Workspace (vertikal) ----
      "Mod+U".focus-workspace-down = {};
      "Mod+I".focus-workspace-up = {};
      "Mod+Ctrl+Left".focus-workspace-up = {};
      "Mod+Ctrl+Right".focus-workspace-down = {};

      # cooldown-ms daempft das Hi-Res-Scrollrad des Keyball, sonst rauscht ein
      # Wisch durch mehrere Workspaces.
      "Mod+WheelScrollDown" = {
        _props.cooldown-ms = 150;
        focus-workspace-down = {};
      };
      "Mod+WheelScrollUp" = {
        _props.cooldown-ms = 150;
        focus-workspace-up = {};
      };

      # ---- Overview + Fensterwechsel ----
      "Mod+Tab" = {
        _props.hotkey-overlay-title = "Overview";
        toggle-overview = {};
      };
      "Alt+Tab".focus-window-previous = {};

      # ---- Fenster/Spalte bewegen ----
      "Mod+Shift+H".move-column-left = {};
      "Mod+Shift+L".move-column-right = {};
      "Mod+Shift+Left".move-column-left = {};
      "Mod+Shift+Right".move-column-right = {};
      "Mod+Shift+J".move-window-down = {};
      "Mod+Shift+K".move-window-up = {};
      "Mod+Shift+Down".move-window-down = {};
      "Mod+Shift+Up".move-window-up = {};
      "Mod+Shift+U".move-column-to-workspace-down = {};
      "Mod+Shift+I".move-column-to-workspace-up = {};

      "Mod+Alt+Left".swap-window-left = {};
      "Mod+Alt+Right".swap-window-right = {};

      "Mod+Ctrl+Shift+H".move-column-to-monitor-left = {};
      "Mod+Ctrl+Shift+L".move-column-to-monitor-right = {};

      # ---- Layout: die eigentliche niri-Geste ----
      # Fenster in die Spalte links von sich einsaugen bzw. wieder rauswerfen.
      # Das ersetzt das, was in Hyprland "Fenster in Richtung X verschieben" war.
      "Mod+Comma" = {
        _props.hotkey-overlay-title = "Fenster in Spalte aufnehmen";
        consume-window-into-column = {};
      };
      "Mod+Period" = {
        _props.hotkey-overlay-title = "Fenster aus Spalte loesen";
        expel-window-from-column = {};
      };

      "Mod+R".switch-preset-column-width = {};
      "Mod+Minus".set-column-width = "-10%";
      "Mod+Equal".set-column-width = "+10%";
      "Mod+Ctrl+F".maximize-column = {};
      "Mod+Ctrl+Return".center-column = {};
      "Mod+Alt+T".toggle-column-tabbed-display = {};

      # Tritt an die Stelle des Special-Workspace-Toggles (Mod+Space /
      # Mod+Shift+Space unter Hyprland).
      "Mod+Space".switch-focus-between-floating-and-tiling = {};
      "Mod+Shift+Space".move-window-to-floating = {};

      # niris Default waere Mod+Shift+Slash. Auf dem Schweizer Layout liegt "/"
      # auf Shift+7, das kollidiert mit Mod+Shift+7. Mod+F1 ist layoutneutral.
      "Mod+F1".show-hotkey-overlay = {};
    };
}
```

- [ ] **Step 2: Import ergänzen**

`./binds-nav.nix` in die `imports`-Liste von `modules/meo/niri/default.nix`.

- [ ] **Step 3: Generierte KDL prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" | sed -n '/^binds {/,/^}/p'
```
Expected: `Mod+1` bis `Mod+0` mit `focus-workspace 1` … `focus-workspace 10`,
`Mod+Shift+1` … `Mod+Shift+0` mit `move-column-to-workspace`, und
`Mod+WheelScrollDown cooldown-ms=150`.

- [ ] **Step 4: Bind-Anzahl gegenprüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" \
  | sed -n '/^binds {/,/^}/p' | grep -cE '^\t(Mod|Alt)'
```
Expected: **61** (20 Workspace-Binds + 41 übrige aus dieser Datei). Diese Zahl
ist verifiziert: der Code aus Step 1 wurde durch `toKDL` und `niri validate`
gejagt und liefert exakt 61 Binds ohne Duplikate. Weicht sie ab, fehlt ein Bind
oder es ist einer zu viel.

- [ ] **Step 5: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 6: Commit**

```bash
git add modules/meo/niri/binds-nav.nix modules/meo/niri/default.nix
git commit -m "feat(niri): Navigations-, Bewegungs- und Layout-Binds"
```

---

### Task 7: Binds — Anwendungen, Noctalia, Screenshots, Hardware

**Files:**
- Create: `modules/meo/niri/binds-apps.nix`
- Modify: `modules/meo/niri/default.nix` (imports)

**Interfaces:**
- Consumes: `settings.binds` aus Task 6 (disjunkte Schlüsselmenge);
  `keymap-popup` und `niri-term-toggle` aus Task 5;
  `browser` und `terminal` aus `hosts/<host>/variables.nix`.
- Produces: den Rest von `settings.binds`.

- [ ] **Step 1: `modules/meo/niri/binds-apps.nix` anlegen**

```nix
# Anwendungs-, Noctalia-, Screenshot- und Hardware-Binds.
#
# Portiert aus modules/upstream/home/hyprland/binds.nix. Die Noctalia-IPC-Syntax
# (noctalia msg panel-toggle …) ist compositor-unabhaengig und bleibt unveraendert.
#
# ENTFALLEN gegenueber Hyprland, mit Begruendung:
#   Mod+Ctrl+D  Dock        -> nwg-dock-hyprland ist Hyprland-only; Noctalia
#                              bringt einen eigenen Dock mit (dock.enabled=true)
#   Mod+Shift+N swaync-reset -> swaync laeuft bei barChoice="noctalia" gar nicht
#   Mod+K       qs-keybinds  -> war unter Hyprland bereits unerreichbar (Keysym K
#                              vs. k bei modmask 64); ersetzt durch das native
#                              show-hotkey-overlay auf Mod+F1 (binds-nav.nix)
#   Mod+Shift+K list-keybinds-> dito; Mod+Shift+K ist jetzt move-window-up
#   Mod+Alt+S   Region-Shot  -> die niri-Screenshot-UI (Mod+S) startet ohnehin
#                              in der Regionsauswahl
#   Mod+Shift+W qs-wallpapers-apply -> war unter Hyprland doppelt belegt; hier
#                              gewinnt eindeutig das Noctalia-Wallpaper-Panel
{host, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
  inherit (vars) browser terminal;
in {
  wayland.windowManager.niri.settings.binds = {
    # ---- Terminal und Anwendungen ----
    "Mod+Return" = {
      _props.hotkey-overlay-title = "Terminal";
      spawn = [terminal];
    };
    "Mod+W" = {
      _props.hotkey-overlay-title = "Browser";
      spawn = [browser];
    };
    "Mod+Y".spawn = ["kitty" "-e" "yazi"];
    "Mod+E".spawn = ["emopicker9000"];
    "Mod+O".spawn = ["obs"];
    "Mod+G".spawn = ["gimp"];
    "Mod+T".spawn = ["thunar"];
    "Mod+Alt+M".spawn = ["pavucontrol"];
    "Mod+Shift+D".spawn = ["discord"];
    "Mod+Alt+W".spawn = ["web-search"];
    "Mod+Ctrl+C".spawn = ["qs-cheatsheets"];

    # Ersatz fuer den pyprland-Scratchpad. Siehe modules/meo/scripts/niri-term-toggle.nix.
    "Mod+Shift+T" = {
      _props.hotkey-overlay-title = "Terminal-Workspace";
      spawn = ["niri-term-toggle"];
    };

    # ---- Noctalia (IPC unveraendert aus binds.nix) ----
    "Mod+D".spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
    "Mod+Shift+Return".spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
    "Mod+M".spawn = ["noctalia" "msg" "panel-toggle" "control-center" "notifications"];
    "Mod+V".spawn = ["noctalia" "msg" "panel-toggle" "clipboard"];
    "Mod+C".spawn = ["noctalia" "msg" "panel-toggle" "control-center"];
    "Mod+X".spawn = ["noctalia" "msg" "panel-toggle" "session"];
    "Mod+Shift+W".spawn = ["noctalia" "msg" "panel-toggle" "wallpaper"];
    "Mod+Alt+P".spawn = ["noctalia" "msg" "settings-toggle"];
    "Mod+Shift+Comma".spawn = ["noctalia" "msg" "settings-toggle"];

    # sleep 0.5 haelt dasselbe Schutzfenster wie unter Hyprland: es gibt
    # Noctalia Zeit, das Lock-Surface zu committen, bevor logind suspendiert.
    "Mod+Alt+L" = {
      _props.hotkey-overlay-title = "Sperren und Suspend";
      spawn-sh = "loginctl lock-session && sleep 0.5 && systemctl suspend";
    };

    # ---- Fenster und Session ----
    "Mod+Q".close-window = {};
    "Mod+F".fullscreen-window = {};
    "Mod+Shift+F".toggle-window-floating = {};
    "Mod+Shift+C".quit = {};

    # ---- Screenshots (nativ statt hyprshot) ----
    "Mod+S" = {
      _props.hotkey-overlay-title = "Screenshot";
      screenshot = {};
    };
    "Mod+Ctrl+S".screenshot-screen = {};
    "Mod+Shift+S".screenshot-window = {};

    # niri hat mit `niri msg pick-color` einen eingebauten Picker, der die Farbe
    # aber nur auf stdout schreibt. wl-color-picker legt sie direkt in die
    # Zwischenablage und zeigt eine Lupe. Native Alternative ohne Extrapaket:
    #   spawn-sh = "niri msg pick-color | wl-copy";
    "Mod+Alt+C".spawn = ["wl-color-picker"];

    # ---- Keyball-Overlays (Toggle statt Halten, siehe Task 5) ----
    "F13".spawn = ["keymap-popup" "1"];
    "F14".spawn = ["keymap-popup" "2"];
    "F15".spawn = ["keymap-popup" "3"];

    # ---- Audio und Helligkeit ----
    # allow-when-locked, damit die Tasten auch auf dem Lockscreen wirken.
    "XF86AudioRaiseVolume" = {
      _props.allow-when-locked = true;
      spawn = ["vol-smart" "up" "5%" "5%" "20%"];
    };
    "XF86AudioLowerVolume" = {
      _props.allow-when-locked = true;
      spawn = ["vol-smart" "down" "5%" "5%" "20%"];
    };
    "XF86AudioMute" = {
      _props.allow-when-locked = true;
      spawn = ["vol-smart" "mute"];
    };
    "XF86AudioPlay" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "play-pause"];
    };
    "XF86AudioPause" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "play-pause"];
    };
    "XF86AudioNext" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "next"];
    };
    "XF86AudioPrev" = {
      _props.allow-when-locked = true;
      spawn = ["playerctl" "previous"];
    };
    "XF86MonBrightnessUp" = {
      _props.allow-when-locked = true;
      spawn = ["bright-smart" "up" "10" "5%" "card0-HDMI-A-1" "0.2"];
    };
    "XF86MonBrightnessDown" = {
      _props.allow-when-locked = true;
      spawn = ["bright-smart" "down" "10" "5%" "card0-HDMI-A-1" "0.2"];
    };
  };
}
```

- [ ] **Step 2: `wl-color-picker` zu den Paketen hinzufügen**

In `modules/meo/niri/default.nix` unterhalb des `wayland.windowManager.niri`-Blocks:

```nix
  # Ersatz fuer hyprpicker, das Hyprland-Protokolle braucht. wl-color-picker
  # setzt auf grim/slurp und damit auf zwlr_screencopy_manager_v1, das niri
  # implementiert.
  home.packages = [pkgs.wl-color-picker];
```

- [ ] **Step 3: Import ergänzen**

`./binds-apps.nix` in die `imports`-Liste von `modules/meo/niri/default.nix`.

- [ ] **Step 4: Generierte KDL prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" \
  | sed -n '/^binds {/,/^}/p' | grep -E 'Mod\+Return|Mod\+Alt\+L|XF86AudioRaise|F13'
```
Expected: `Mod+Return hotkey-overlay-title="Terminal"`,
`Mod+Alt+L hotkey-overlay-title="Sperren und Suspend"`,
`XF86AudioRaiseVolume allow-when-locked=true`, `F13`.

- [ ] **Step 5: Auf Kollisionen prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" \
  | sed -n '/^binds {/,/^}/p' | grep -oE '^\t[A-Za-z0-9+]+' | sort | uniq -d
```
Expected: leere Ausgabe. (Wäre etwas doppelt, hätte `niri validate` den Build
bereits abgebrochen — dieser Schritt macht sichtbar, *was* doppelt wäre.)

Zusätzlich die Gesamtzahl:

```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" \
  | sed -n '/^binds {/,/^}/p' | grep -cE '^\t([A-Za-z0-9]|Mod|Alt|XF86|F1)'
```
Expected: **103** (61 aus `binds-nav.nix` + 42 aus dieser Datei). Auch diese
Zahl ist vorab durch `toKDL` + `niri validate` bestätigt.

- [ ] **Step 6: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 7: Commit**

```bash
git add modules/meo/niri/binds-apps.nix modules/meo/niri/default.nix
git commit -m "feat(niri): Anwendungs-, Noctalia-, Screenshot- und Hardware-Binds"
```

---

### Task 8: Fensterregeln, term-Workspace und Autostart

**Files:**
- Create: `modules/meo/niri/rules.nix`
- Create: `modules/meo/niri/startup.nix`
- Modify: `modules/meo/niri/default.nix` (imports)

**Interfaces:**
- Consumes: `settings._children` aus Task 3 (wird konkateniert).
- Produces: den Workspace `term`, auf den `niri-term-toggle` aus Task 5
  springt, und die `window-rule`-Kette.

**Wichtig:** Alle `window-rule`-Blöcke gehören in **diese eine Datei**. Bei niri
gewinnt die zuletzt passende Regel; über Modulgrenzen hinweg ist die
Listenreihenfolge nicht vorhersagbar.

- [ ] **Step 1: `modules/meo/niri/rules.nix` anlegen**

```nix
# Benannter Workspace + Fensterregeln.
#
# Nur eine Teilmenge der 400+ Zeilen aus modules/upstream/home/hyprland/
# windowrules.nix wird portiert. niris window-rule kann app-id/title matchen und
# open-floating, open-maximized, open-on-workspace, Geometrie, Opacity sowie
# block-out-from setzen — aber nicht das volle Hyprland-Vokabular. Der Rest
# wandert nach Bedarf nach, wenn im Alltag etwas auffaellt.
#
# REIHENFOLGE IST BEDEUTSAM: bei niri gewinnt die zuletzt passende Regel.
# Deshalb steht die generische Geometrie-Regel zuerst und die spezifischen
# danach. Alle Regeln muessen in dieser einen Datei bleiben.
{...}: {
  wayland.windowManager.niri.settings._children = [
    # Der Workspace, auf den niri-term-toggle (Mod+Shift+T) springt.
    {workspace._args = ["term"];}

    # Generische Optik fuer alle Fenster.
    {
      window-rule._children = [
        {geometry-corner-radius = 8;}
        {clip-to-geometry = true;}
      ];
    }

    # Dropdown-Terminal-Ersatz: eigene app-id, liegt fest auf "term".
    {
      window-rule._children = [
        {match._props.app-id = "^ghostty-term$";}
        {open-on-workspace = "term";}
        {open-maximized = true;}
      ];
    }

    # Kleine Dialoge sollen nicht das Spaltenlayout aufreissen.
    {
      window-rule._children = [
        {match._props.app-id = "^org.pulseaudio.pavucontrol$";}
        {match._props.app-id = "^nm-connection-editor$";}
        {match._props.app-id = "^blueman-manager$";}
        {match._props.app-id = "^org.gnome.Calculator$";}
        {open-floating = true;}
      ];
    }

    # Picture-in-Picture unten rechts, schwebend.
    {
      window-rule._children = [
        {match._props.title = "^Picture-in-Picture$";}
        {open-floating = true;}
        {
          default-floating-position._props = {
            x = 32;
            y = 32;
            relative-to = "bottom-right";
          };
        }
      ];
    }

    # Passwortmanager nicht in Screenshares/Aufnahmen durchreichen.
    {
      window-rule._children = [
        {match._props.app-id = "^1Password$";}
        {block-out-from = "screen-capture";}
      ];
    }
  ];
}
```

- [ ] **Step 2: `modules/meo/niri/startup.nix` anlegen**

```nix
# Autostart.
#
# Portiert aus modules/upstream/home/hyprland/exec-once.nix. ENTFALLEN:
#   - dbus-update-activation-environment / systemctl --user import-environment:
#     `niri --session` importiert die Umgebung selbst. Genau deshalb setzt das
#     nixpkgs-Modul enableDefaultPath = false auf der Unit.
#   - qs -c overview: Overview ist in niri eingebaut (Mod+Tab).
#   - killall waybar/swaync: unter niri startet keines von beiden.
#   - swww-daemon: Noctalia v5 macht das Wallpaper selbst (wallpaper.enabled).
#     Sollte der Hintergrund leer bleiben, ist das der erste Verdaechtige.
#
# hyprpolkitagent laeuft als systemd-User-Unit und ist compositor-unabhaengig.
# Noctalia bringt mit shell.polkit_agent = true einen eigenen mit — falls beim
# ersten Login zwei Passwortdialoge auftauchen, diese Zeile streichen.
{...}: {
  wayland.windowManager.niri.settings = {
    spawn-at-startup = [
      ["wl-paste" "--type" "text" "--watch" "cliphist" "store"]
      ["wl-paste" "--type" "image" "--watch" "cliphist" "store"]
      ["systemctl" "--user" "start" "hyprpolkitagent"]
      # Terminal fuer den term-Workspace; die window-rule in rules.nix
      # platziert es dort.
      ["ghostty" "--class=ghostty-term"]
    ];

    # Verzoegert, damit Stylix zuerst fertig ist und danach das Nutzer-Wallpaper
    # mit genau einem Wechsel gewinnt — gleiche Logik wie unter Hyprland.
    spawn-sh-at-startup = [
      "sleep 2 && (qs-wallpapers-restore >/dev/null 2>&1 || true)"
    ];
  };
}
```

- [ ] **Step 3: Imports ergänzen**

`./rules.nix` und `./startup.nix` in die `imports`-Liste von
`modules/meo/niri/default.nix`.

- [ ] **Step 4: Generierte KDL prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" \
  | grep -E '^workspace|^window-rule|^spawn'
```
Expected: `workspace "term"`, sechs `window-rule {`-Zeilen, vier
`spawn-at-startup`-Zeilen und eine `spawn-sh-at-startup`-Zeile.

- [ ] **Step 5: Regelreihenfolge prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" \
  | grep -A3 '^window-rule' | head -30
```
Expected: die generische Regel mit `geometry-corner-radius` steht **vor** den
`match`-Regeln. Ist die Reihenfolge vertauscht, überschreibt die generische
Regel die spezifischen.

- [ ] **Step 6: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 7: Commit**

```bash
git add modules/meo/niri/rules.nix modules/meo/niri/startup.nix modules/meo/niri/default.nix
git commit -m "feat(niri): Fensterregeln, term-Workspace und Autostart"
```

---

### Task 9: GPU-Wahl beim Docken

Spiegelt `modules/meo/hyprland-gpu-smart.nix`. Weil niri kein `include` in KDL
kennt, setzt der Wrapper die Config zur Laufzeit zusammen und startet niri mit
`-c`.

**Files:**
- Create: `modules/meo/niri-gpu-smart.nix`
- Modify: `hosts/meo/default.nix` (imports)

**Interfaces:**
- Consumes: `~/.config/niri/config.kdl` (der HM-Symlink aus Task 1–8).
- Produces: das Kommando `niri-smart` und die Session `niri-smart`
  ("niri (Smart GPU)"), auf die Task 11 `defaultSession` zeigt.

- [ ] **Step 1: `modules/meo/niri-gpu-smart.nix` anlegen**

```nix
{pkgs, ...}:
# Dock-abhaengige GPU-Wahl fuer niri auf Host meo (Intel Arc iGPU + NVIDIA RTX 4080).
#
# Gleiche Ausgangslage wie bei modules/meo/hyprland-gpu-smart.nix: externe
# Monitore haengen an der NVIDIA-dGPU. Rendert der Compositor auf der iGPU, wird
# jeder Frame ueber PCIe kopiert -> Cursor-Lag. Im mobilen Betrieb soll die dGPU
# dagegen nach D3cold fallen duerfen.
#
# Unterschied zu Hyprland: niri kennt kein AQ_DRM_DEVICES. Die Renderer-Wahl
# sitzt in der Config unter debug { render-drm-device "..." }. Und weil niri
# KEIN include in KDL unterstuetzt (verifiziert: `niri validate` bricht mit
# Parse-Fehler), kann kein Fragment nachgeladen werden. Stattdessen: die
# HM-Config kopieren, den passenden debug-Block anhaengen und niri mit -c auf
# die Kopie zeigen lassen.
#
# WICHTIG: In modules/meo/niri/ darf deshalb KEIN debug-Block stehen, sonst
# entsteht er hier doppelt.
let
  nvidiaPci = "0000:01:00.0";
  intelPci = "0000:00:02.0";

  niriSmart = pkgs.writeShellApplication {
    name = "niri-smart";
    runtimeInputs = with pkgs; [coreutils findutils gnugrep niri];
    text = ''
      set -u

      resolve_render_node() {
        local pci="$1" node
        node=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'renderD*' -printf '%f\n' 2>/dev/null | head -n1) || true
        if [ -n "''${node:-}" ] && [ -e "/dev/dri/$node" ]; then
          printf '%s\n' "/dev/dri/$node"
        fi
      }

      resolve_card() {
        local pci="$1" card
        card=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'card*' -printf '%f\n' 2>/dev/null | head -n1) || true
        printf '%s\n' "''${card:-}"
      }

      nvidia_node=$(resolve_render_node "${nvidiaPci}")
      intel_node=$(resolve_render_node "${intelPci}")
      nvidia_card=$(resolve_card "${nvidiaPci}")

      external_connected=0
      if [ -n "$nvidia_card" ]; then
        for status in /sys/class/drm/"$nvidia_card"-*/status; do
          [ -e "$status" ] || continue
          name=$(basename "$(dirname "$status")")
          case "$name" in
            *eDP*) continue ;;
          esac
          if [ "$(cat "$status")" = "connected" ]; then
            external_connected=1
            break
          fi
        done
      fi

      if [ "$external_connected" = "1" ] && [ -n "$nvidia_node" ]; then
        render_node="$nvidia_node"
        mode="docked: NVIDIA als Renderer"
      elif [ -n "$intel_node" ]; then
        render_node="$intel_node"
        mode="mobil: Intel, NVIDIA darf schlafen"
      else
        render_node=""
        mode="fallback: keine GPU-Bindung (Nodes nicht aufloesbar)"
      fi

      printf '[niri-smart] %s -- render-drm-device=%s\n' "$mode" "''${render_node:-unset}" >&2

      base="$HOME/.config/niri/config.kdl"
      generated="''${XDG_RUNTIME_DIR:-/tmp}/niri-config.kdl"

      if [ ! -r "$base" ]; then
        printf '[niri-smart] %s fehlt, starte mit Default-Config\n' "$base" >&2
        exec niri --session "$@"
      fi

      cp "$base" "$generated"
      if [ -n "$render_node" ]; then
        {
          printf '\n// von niri-smart ergaenzt (%s)\n' "$mode"
          printf 'debug {\n    render-drm-device "%s"\n}\n' "$render_node"
        } >> "$generated"
      fi

      # Bricht lieber hier ab als in einer schwarzen Session.
      if ! niri validate --config "$generated"; then
        printf '[niri-smart] generierte Config ungueltig, starte mit HM-Config\n' >&2
        exec niri --session "$@"
      fi

      exec niri --session -c "$generated" "$@"
    '';
  };

  niriSmartSession = pkgs.runCommand "niri-smart-session" {
    passthru.providedSessions = ["niri-smart"];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/niri-smart.desktop <<'EOF'
    [Desktop Entry]
    Name=niri (Smart GPU)
    Comment=niri mit Auto-Erkennung der NVIDIA-GPU beim Docken
    Exec=niri-smart
    Type=Application
    EOF
  '';
in {
  environment.systemPackages = [niriSmart];
  services.displayManager.sessionPackages = [niriSmartSession];
}
```

- [ ] **Step 2: Import in `hosts/meo/default.nix` ergänzen**

Direkt nach `../../modules/meo/hyprland-gpu-smart.nix`:

```nix
    ../../modules/meo/niri-gpu-smart.nix
```

- [ ] **Step 3: Wrapper bauen (ShellCheck)**

Run:
```bash
cd ~/nixos-config
nix build --no-link --print-out-paths '.#nixosConfigurations.meo.config.system.build.toplevel'
```
Expected: Erfolg. `writeShellApplication` lässt ShellCheck laufen; Quoting-Fehler
brechen hier.

- [ ] **Step 4: Session ist registriert**

Run:
```bash
cd ~/nixos-config
nix eval '.#nixosConfigurations.meo.config.services.displayManager.sessionPackages' \
  --apply 'ps: builtins.concatLists (map (p: p.providedSessions or []) ps)'
```
Expected: Liste enthält `"hyprland-smart"` und `"niri-smart"`.

- [ ] **Step 5: Wrapper trocken prüfen**

Run:
```bash
cd ~/nixos-config
S=$(nix build --no-link --print-out-paths '.#nixosConfigurations.meo.config.system.build.toplevel')
grep -n 'render-drm-device' "$(grep -l niri-smart "$S"/sw/bin/* 2>/dev/null | head -1)" 2>/dev/null \
  || echo "Script im Store, Inhalt via: cat \$(readlink -f $S/sw/bin/niri-smart)"
```
Expected: der `debug`-Block taucht im generierten Script auf.

- [ ] **Step 6: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich. (`niri-gpu-smart.nix` wird nur von
`hosts/meo/default.nix` importiert, meo-work bleibt unberührt.)

- [ ] **Step 7: Commit**

```bash
git add modules/meo/niri-gpu-smart.nix hosts/meo/default.nix
git commit -m "feat(niri): Smart-GPU-Session ueber NIRI_CONFIG-Wrapper"
```

---

### Task 10: Bestehende Hyprland-Kopplungen compositor-aware machen

Zwei bestehende Bausteine rufen `hyprctl` und täten unter niri stillschweigend
nichts. Beide bekommen eine Fallunterscheidung statt eines Rewrites.

**Files:**
- Modify: `hosts/meo/default.nix` (`systemd.user.services.edp-refresh-switcher`)
- Modify: `modules/meo/scripts/travel-mode.nix`

**Interfaces:**
- Consumes: nichts aus früheren Tasks.
- Produces: nichts für spätere Tasks. Reine Reparatur bestehender Bausteine.

- [ ] **Step 1: Den `ExecStart`-Block ersetzen**

Der bestehende Block in `hosts/meo/default.nix` setzt die Refresh-Rate per
`hyprctl`. Ersetze den `set_rate`-Teil so, dass er beide Compositor kennt.
Der umgebende Service-Block (`description`, `wantedBy`, `partOf`, `Restart`,
`RestartSec`) bleibt unverändert; nur `ExecStart` wird getauscht:

```nix
      ExecStart = pkgs.writeShellScript "edp-refresh-switcher" ''
        export PATH=/run/current-system/sw/bin:$PATH
        # MODIFIED 2026-08-27 (niri-Migration): erkennt die laufende Session und
        # spricht entweder niri oder Hyprland an. Vorher hart auf hyprctl.
        #
        # Einschraenkung unveraendert: `niri msg output` ist laut --help
        # ausdruecklich temporaer und wird bei einer Config-Aenderung vergessen —
        # genau wie ein Hyprland-Config-Reload wieder 240Hz setzt. Der naechste
        # AC-Wechsel korrigiert das.
        set_rate() {
          rate="$1"
          if [ -n "''${NIRI_SOCKET:-}" ] || [ -S "$XDG_RUNTIME_DIR/niri.wayland.1.sock" ]; then
            niri msg output eDP-1 mode "2560x1600@$rate" >/dev/null 2>&1 && return 0
          fi
          HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
          export HYPRLAND_INSTANCE_SIGNATURE
          [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || return 0
          hyprctl keyword monitor "eDP-1,2560x1600@$rate,0x0,1.6" >/dev/null
        }
        apply() {
          if [ "$(cat /sys/class/power_supply/ACAD/online)" = "1" ]; then
            [ "$last" = ac ] || { last=ac; set_rate 240; }
          else
            [ "$last" = bat ] || { last=bat; set_rate 60; }
          fi
        }
        last=""
        apply
        upower --monitor | while read -r _; do apply; done
      '';
```

- [ ] **Step 2: `modules/meo/scripts/travel-mode.nix` compositor-aware machen**

Das Script schaltet den Bildschirm per `hyprctl dispatch dpms off|on` ab und an
(Zeilen 14 und 24). niri hat dafür `power-off-monitors` / `power-on-monitors`.

`runtimeInputs` erweitern:

```nix
  runtimeInputs = with pkgs; [
    coreutils
    hyprland
    niri
  ];
```

Im `text`-Block eine Hilfsfunktion direkt nach der `STATE_FILE`-Zeile einfügen:

```bash
    # MODIFIED 2026-08-27 (niri-Migration): DPMS je nach laufender Session.
    # Vorher hart `hyprctl dispatch dpms`, was unter niri wirkungslos war —
    # der Bildschirm waere im Travel-Mode angeblieben.
    dpms() {
      if [ -n "''${NIRI_SOCKET:-}" ]; then
        niri msg action "power-$1-monitors" 2>/dev/null || true
      else
        hyprctl dispatch dpms "$1" 2>/dev/null || true
      fi
    }
```

Dann in `activate()` die Zeile `hyprctl dispatch dpms off 2>/dev/null || true`
durch `dpms off` ersetzen und in `deactivate()` entsprechend
`hyprctl dispatch dpms on 2>/dev/null || true` durch `dpms on`.

Achtung auf die Nix-Escapes: im `text`-Block einer `writeShellApplication` muss
`${NIRI_SOCKET:-}` als `''${NIRI_SOCKET:-}` geschrieben werden, sonst
interpoliert Nix.

- [ ] **Step 3: Generierte Unit prüfen**

Run:
```bash
cd ~/nixos-config
cat "$(nix eval --raw '.#nixosConfigurations.meo.config.systemd.user.services.edp-refresh-switcher.serviceConfig.ExecStart')"
```
Expected: das Script enthält sowohl den `niri msg output`- als auch den
`hyprctl keyword monitor`-Zweig.

- [ ] **Step 4: travel-mode baut und besteht ShellCheck**

Run:
```bash
cd ~/nixos-config
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.meo.config.home-manager.users.meo.home.path'
```
Expected: Erfolg. Ein falsch escapetes `''${NIRI_SOCKET:-}` bricht hier.

- [ ] **Step 5: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 6: Commit**

```bash
git add hosts/meo/default.nix modules/meo/scripts/travel-mode.nix
git commit -m "fix(meo): edp-refresh-switcher und travel-mode sprechen niri und Hyprland"
```

---

### Task 11: Umschalten und erster Login

Erst hier wechselt die Default-Session. Alles davor ist additiv und
zurücknehmbar.

**Files:**
- Modify: `hosts/meo/default.nix` (`services.displayManager.defaultSession`)

**Interfaces:**
- Consumes: die Session `niri-smart` aus Task 9.
- Produces: nichts.

- [ ] **Step 1: Default-Session umstellen**

In `hosts/meo/default.nix` die Zeile aus Task 1 ersetzen:

```nix
  # MODIFIED 2026-08-27: von "hyprland" auf niri umgestellt (Ende der Migration).
  # Rueckweg ohne Rebuild: in SDDM unten links die Session "Hyprland (Smart GPU)"
  # waehlen. Die Hyprland-Module bleiben vollstaendig im Repo.
  services.displayManager.defaultSession = lib.mkForce "niri-smart";
```

- [ ] **Step 2: Beide Hosts bauen**

Run: `nh os build --hostname meo && nh os build --hostname meo-work`
Expected: beide erfolgreich.

- [ ] **Step 3: Die vier Sessions gegenprüfen**

Run:
```bash
cd ~/nixos-config
nix eval '.#nixosConfigurations.meo.config.services.displayManager.sessionPackages' \
  --apply 'ps: builtins.concatLists (map (p: p.providedSessions or []) ps)'
nix eval --raw '.#nixosConfigurations.meo.config.services.displayManager.defaultSession'
```
Expected: die Liste enthält `hyprland-smart` und `niri-smart` (plus die von den
Compositor-Paketen gelieferten `hyprland` und `niri`); `defaultSession` ist
`niri-smart`.

- [ ] **Step 4: Anwenden**

Run: `fr`
Expected: erfolgreich. `fr` committet und pusht dabei automatisch.

- [ ] **Step 5: Abmelden und in niri anmelden**

Rückweg ist jederzeit die Session-Auswahl in SDDM.

- [ ] **Step 6: Login-Checkliste abarbeiten**

Der Reihe nach, weil frühe Punkte spätere erklären:

1. **`Mod+Shift+1`** — greifen die Workspace-Binds auf CH-Layout überhaupt?
   Das ist der einzige Punkt, den `niri validate` nicht prüfen konnte
   (Spec Abschnitt 11.6). Funktioniert es nicht, in `binds-nav.nix` die
   `wsKeys`-Liste auf die Shift-Level-Keysyms umstellen
   (`plus`, `quotedbl`, `asterisk`, `ccedilla`, …) und `niri msg keyboard-layouts`
   zur Kontrolle heranziehen.
2. **Monitore:** `niri msg outputs` — eDP-1 auf 2560x1600@240 mit Scale 1.6,
   DP-1 mit Scale 1.2 bei x=1600.
3. **XWayland:** Affinity oder Bambu Studio starten. Scharf und in richtiger
   Größe? Das ist der eigentliche Test für den Migrationsgrund.
4. **Noctalia:** Bar sichtbar, `Mod+D` Launcher, `Mod+V` Clipboard, `Mod+C`
   Control-Center.
5. **Wallpaper:** vorhanden? Wenn nicht, ist `swww-daemon` der Verdächtige
   (siehe Kommentar in `startup.nix`).
6. **Polkit:** eine Aktion mit Rechteabfrage auslösen. Zwei Dialoge = die
   `hyprpolkitagent`-Zeile in `startup.nix` streichen.
7. **`Mod+Tab`** Overview, **`Mod+Comma`/`Mod+Period`** Consume/Expel,
   **`Mod+R`** Spaltenbreite.
8. **`Mod+F1`** Hotkey-Übersicht — dort stehen die `hotkey-overlay-title`-Texte.
9. **`Mod+Alt+L`** sperren und suspendieren, danach Resume prüfen.
10. **Akku:** Netzteil ziehen, dann `niri msg outputs` — eDP-1 auf 60 Hz.
11. **Docking:** externen Monitor anschließen, ab- und wieder anmelden.
    `journalctl --user -b | grep niri-smart` zeigt die gewählte Karte.
12. **Maus-Binds** (Spec Abschnitt 11.1): unter Hyprland lagen `Mod+LMB` auf
    Verschieben und `Mod+RMB` auf Größe ändern (`bindm`). Ob niri das
    konfigurierbar macht, ist nicht verifiziert. Ein schwebendes Fenster mit
    gedrückter Mod-Taste ziehen — geht es von Haus aus, ist nichts zu tun.
13. **Travel-Mode:** `travel-mode on` — geht der Bildschirm aus?
    `travel-mode off` — kommt er zurück? (Task 10, Schritt 2.)

- [ ] **Step 7: Ergebnisse festhalten**

Was in Schritt 6 nicht funktioniert hat, als nummerierte Liste an Abschnitt 11
der Spec anhängen. Jeder Punkt wird ein eigener Folge-Task — nicht in diesem
Plan nachbessern.

---

## Rollback

- **Sofort, ohne Rebuild:** in SDDM „Hyprland (Smart GPU)" wählen.
- **Default zurückdrehen:** in `hosts/meo/default.nix`
  `defaultSession = lib.mkForce "hyprland-smart";`, dann `fr`.
- **Ganz zurück:** `./niri` aus `modules/meo/default.nix` und
  `programs.niri.enable` plus den `niri-gpu-smart.nix`-Import aus
  `hosts/meo/default.nix` entfernen. Die Dateien unter `modules/meo/niri/`
  dürfen liegen bleiben — ohne Import sind sie wirkungslos.
