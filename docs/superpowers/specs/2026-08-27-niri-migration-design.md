# niri-Migration (Host `meo`) — Design-Spec

Datum: 2026-08-27
Status: entworfen, nicht implementiert
Betroffener Host: `meo` (nvidia-laptop). `meo-work` bleibt unangetastet.

## 1. Problem & Kontext

Hyprland stört an zwei konkreten Achsen (vom Nutzer benannt):

1. **Fenster-/Workspace-Handling** — dynamisches Tiling zwingt Fenster bei jedem
   neuen Fenster in neue Größen; Workspaces sind feste, nummerierte Container.
2. **Multi-Monitor & Skalierung** — dokumentiert in
   `hyprland-live-scale-breaks-xwayland`: `hyprctl keyword monitor` lässt
   X11-Fenster auf 1x zusammenschrumpfen, weil XWayland in Hyprland kein
   eigenes fraktionales Scaling kann.

Ausdrücklich **nicht** Anlass der Migration: die Freeze-/Stabilitätshistorie
(`noctalia-egl-freeze-after-resume`, `meo-edp-psr-freeze`). Diese Ursachen
sitzen in i915/Panel/Kernel und wandern mit. Die Migration ist kein Freeze-Fix.

niri ist ein scrollable-tiling Compositor (Rust/smithay). Spalten liegen auf
einem horizontal unendlichen Band; ein neues Fenster wird angehängt statt
eingepasst, bestehende Fenster behalten ihre Größe. Workspaces sind dynamisch
und pro Monitor vertikal gestapelt. XWayland läuft als externer Prozess
(`xwayland-satellite`), nicht compositor-intern.

## 2. Ziele / Nicht-Ziele

**Ziele**
- niri wird Standard-Session auf `meo`, alltagstauglich ab dem ersten Login.
- Hyprland bleibt vollständig im Repo und in SDDM wählbar (Rückweg ohne Rebuild).
- Noctalia bleibt die Shell (Bar, Dock, Launcher, Lock, Notifications, Clipboard).
- Monitor-Setup (eDP-1 1.6x / DP-1 1.2x) verhält sich wie heute oder besser.
- Kein neuer Flake-Input.

**Nicht-Ziele**
- `meo-work` migrieren (später, eine Zeile in dessen `variables.nix`).
- Hyprland-Module entfernen oder gaten (erst wenn niri sich bewährt hat).
- Die 400+ Zeilen `windowrules.nix` vollständig portieren.
- Freeze-/Suspend-Verhalten verbessern.

## 3. Verifizierte Grundlagen

Alle folgenden Punkte wurden am echten Binary/Modul geprüft, nicht aus dem
Gedächtnis übernommen:

| Fakt | Verifikation |
|---|---|
| `niri` 26.04 in nixpkgs-Pin | `nix eval nixpkgs#niri.version` |
| `xwayland-satellite` 0.8.2 | `nix eval nixpkgs#xwayland-satellite.version` |
| Home-Manager-Pin hat `wayland.windowManager.niri` | `modules/services/window-managers/niri.nix` (214 Z.) |
| Build-Zeit-Validierung der KDL | `checkConfig` → `niri validate --config "$target"` in `checkPhase` |
| nixpkgs `programs.niri` liefert Session + Portals + systemd-Units | `nixos/modules/programs/wayland/niri.nix` |
| Noctalia v5 spricht niri nativ | `NIRI_SOCKET` + 187 `Niri`-Symbole im Binary |
| `include` existiert **nicht** in niri-KDL | `niri validate` bricht mit Parse-Fehler ab |
| `NIRI_CONFIG` env + `-c` Flag | `niri --help` |
| `niri msg output <O> mode/scale/position/vrr` | `niri msg output --help` |
| `zwlr_screencopy_manager_v1` implementiert | Symbole im Binary → grim/slurp/wl-color-picker laufen |
| Bind-Properties: nur `repeat`, `allow-when-locked`, `cooldown-ms`, `hotkey-overlay-title`, `allow-inhibiting` | `niri validate`; `on-release` → `unexpected property` |
| Doppelte Binds werden abgelehnt | `niri validate` → `unexpected keybind` |
| Nix-Attrset → KDL → `niri validate` funktioniert | `toKDL` aus HM-Pin gegen Probe-Attrset ausgeführt und validiert |
| `toggle-overview`, `screenshot*`, `consume-/expel-window-*` | `niri msg action` Aktionsliste |
| `wl-color-picker` 1.4 in nixpkgs | `nix eval nixpkgs#wl-color-picker.version` |

Eine Probe-Config mit allen riskanten Optionen (Output-Modi, Scale, Position,
VRR, `xwayland-satellite`, `debug { render-drm-device }`, Binds mit Argumenten
und Properties, `window-rule`, `preset-column-widths`) wurde erfolgreich gegen
`niri validate` geprüft.

## 4. Getroffene Entscheidungen

| Frage | Entscheidung | Begründung |
|---|---|---|
| Umfang | Direkter Umstieg, Hyprland als Fallback-Session | Nutzerwahl |
| Hosts | Nur `meo` | `meo-work` bleibt berechenbar |
| Keybinds | Hybrid: exec-Binds + `Mod+1..0` bleiben, Navigation wird niri-idiomatisch | Muskelgedächtnis wo möglich, niri-Modell wo nötig |
| Schaltmechanik | Beide Compositor installiert, `defaultSession = "niri"` | Rollback ohne Rebuild |
| Config-Erzeugung | HM-Modul aus nixpkgs-Pin, kein `niri-flake` | Kein zusätzlicher Input; passt zum Flake-Cleanup 2026-08-20 |
| Dropdown-Terminal | Benannter Workspace `term` | Deklarativ, kein Extra-Tool |
| Color Picker | `wl-color-picker` statt `hyprpicker` | hyprpicker braucht Hyprland-Protokolle |

## 5. Architektur

### 5.1 Modulstruktur

```
modules/meo/niri/
├── default.nix     Aggregator; wayland.windowManager.niri.enable, Pakete
├── outputs.nix     Monitor-Config, liest hosts/<host>/variables.nix
├── layout.nix      Spalten-Layout, Gaps, Focus-Ring, Animationen, Overview
├── binds.nix       Keybinds (Abschnitt 7)
├── rules.nix       window-rules (portierte Teilmenge)
└── startup.nix     spawn-at-startup

modules/meo/niri-gpu-smart.nix   Docking-abhängige GPU-Wahl (Abschnitt 9)
```

Begründung der Ablage: `CLAUDE.md` schreibt für neue Module `modules/meo/` vor.
`modules/upstream/` bleibt unberührt — es gibt keine Änderung, die beide Hosts
wollen.

### 5.2 Systemseite

Ausschließlich in `hosts/meo/default.nix` (Regel „Make a change just for one
host"), **nicht** in `modules/upstream/core/packages.nix`:

```nix
programs.niri.enable = true;
services.displayManager.defaultSession = "niri";
```

Wichtig: `fr` committet und pusht jede Änderung auf beide Hosts. Weil der
System-Schalter host-lokal liegt, bekommt `meo-work` den niri-Code zwar ins
Repo, aber niemals in seine Session.

### 5.3 Was das nixpkgs-Modul bereits erledigt

`services.displayManager.sessionPackages`, `systemd.user.services.niri`
(mit `restartIfChanged = false` und `enableDefaultPath = false`),
`xdg.portal` mit `gnome` + `gtk` und `xdg-desktop-portal-gnome` als
`extraPortals`, sowie `gnome-keyring`. Es setzt `defaultSession` selbst per
`mkDefault "niri"` — wir setzen es trotzdem explizit, damit die Absicht im
Host-File sichtbar ist.

### 5.4 Home-Manager-Seite

`wayland.windowManager.niri.settings` ist ein Attrset, das über
`lib.hm.generators.toKDL` nach `~/.config/niri/config.kdl` übersetzt wird.
Konventionen des Generators (aus der Modul-Doku):

- `{}` → Leaf-Node ohne Argumente (`prefer-no-csd = {}`)
- `_props` → benannte Properties (`position._props = { x = 0; y = 0; }`)
- `_children` → geordnete/wiederholte Kinder
- `_args` → Argumente an wiederholten Top-Level-Nodes (`output._args = ["eDP-1"]`)

`extraConfig` / `extraConfigEarly` stehen als Roh-KDL-Notausgang bereit, falls
der Generator eine Struktur nicht abbildet.

## 6. Monitor & Skalierung

Übernommen aus `hosts/meo/variables.nix` `extraMonitorSettings`:

```kdl
output "eDP-1" {
    mode "2560x1600@240.000"
    scale 1.6
    position x=0 y=0
    variable-refresh-rate on-demand=true
}
output "DP-1" {
    scale 1.2
    position x=1600 y=141
}
```

niri rechnet Positionen in **logischen** Koordinaten: 2560 / 1.6 = 1600. Die
Hyprland-Werte übertragen sich damit unverändert.

### Akku-Refresh-Switcher

`systemd.user.services.edp-refresh-switcher` in `hosts/meo/default.nix` ruft
heute `hyprctl keyword monitor`. Er wird compositor-aware:

- `$NIRI_SOCKET` gesetzt → `niri msg output eDP-1 mode 2560x1600@60`
- sonst `$XDG_RUNTIME_DIR/hypr` vorhanden → bisheriger `hyprctl`-Pfad

Damit funktioniert der Dienst in beiden Sessions statt still zu brechen.

**Bekannte Einschränkung, unverändert:** `niri msg output` ändert die
Konfiguration laut `--help` ausdrücklich nur temporär und vergisst sie, wenn
sich die Output-Konfiguration in der Config-Datei ändert. Das ist dieselbe
Einschränkung, die der Hyprland-Kommentar schon beschreibt („Config-Reload
setzt wieder 240Hz"). Die Migration behebt sie nicht.

## 7. Keybinds

### 7.1 Unverändert übernommen (`spawn`)

`Mod+Return` Terminal · `Mod+W` Browser · `Mod+Y` Yazi · `Mod+E` Emoji ·
`Mod+O` OBS · `Mod+G` GIMP · `Mod+T` Thunar · `Mod+Alt+M` pavucontrol ·
`Mod+Shift+D` Discord · `Mod+Alt+W` Web-Search · `Mod+Ctrl+C` Cheatsheets ·
alle Noctalia-IPC-Binds (`Mod+D`, `Mod+Shift+Return`, `Mod+M`, `Mod+V`,
`Mod+C`, `Mod+X`, `Mod+Alt+P`, `Mod+Shift+Comma`, `Mod+Alt+L`) ·
Media-/Brightness-Keys mit `allow-when-locked=true`.

**Korrektur gegenüber dem ersten Entwurf:** `F13`/`F14`/`F15` können **nicht**
1:1 übernommen werden. niri 26.04 kennt keine Release-Bindings — gültige
Bind-Properties sind ausschließlich `repeat`, `allow-when-locked`,
`cooldown-ms`, `hotkey-overlay-title` und `allow-inhibiting`
(`on-release=true` scheitert mit `unexpected property`). Das heutige
`bind`/`bindr`-Paar (drücken zeigt, loslassen versteckt) wird deshalb zu einem
**Toggle**: ein Script `keymap-popup <layer>` startet `imv`, wenn keines läuft,
und killt es sonst. Aufruf per `spawn-sh`.

### 7.2 Navigation

| Taste | niri-Aktion | Änderung |
|---|---|---|
| `Mod+H` / `Mod+L` | `focus-column-left` / `-right` | Achse: Spalte statt Richtung |
| `Mod+Left` / `Mod+Right` | dito | dito |
| `Mod+J` / `Mod+K` | `focus-window-down` / `-up` | wie heute |
| `Mod+Down` / `Mod+Up` | dito | dito |
| `Mod+U` / `Mod+I` | `focus-workspace-down` / `-up` | neu |
| `Mod+Ctrl+Left/Right` | `focus-workspace-up` / `-down` | Muskelgedächtnis erhalten |
| `Mod+1` … `Mod+0` | `focus-workspace 1..10` | wie heute |
| `Mod+Scroll` | `focus-workspace-down/-up` | wie heute |
| `Alt+Tab` | `focus-window-previous` | ersetzt `cyclenext` |
| `Mod+Tab` | `toggle-overview` | **nativ**, ersetzt `qs -c overview` |

### 7.3 Fenster bewegen

| Taste | niri-Aktion |
|---|---|
| `Mod+Shift+H/L`, `Mod+Shift+Left/Right` | `move-column-left` / `-right` |
| `Mod+Shift+J/K`, `Mod+Shift+Down/Up` | `move-window-down` / `-up` |
| `Mod+Shift+U` / `Mod+Shift+I` | `move-column-to-workspace-down` / `-up` |
| `Mod+Shift+1` … `Mod+Shift+0` | `move-column-to-workspace 1..10` |
| `Mod+Alt+Left/Right` | `swap-window-left` / `-right` |
| `Mod+Ctrl+Shift+H/L` | `move-column-to-monitor-left` / `-right` |

### 7.4 Layout (neu, ohne Hyprland-Vorbild)

| Taste | niri-Aktion |
|---|---|
| `Mod+Comma` | `consume-window-into-column` |
| `Mod+Period` | `expel-window-from-column` |
| `Mod+R` | `switch-preset-column-width` |
| `Mod+Minus` / `Mod+Equal` | `set-column-width "-10%"` / `"+10%"` |
| `Mod+Ctrl+F` | `maximize-column` |
| `Mod+Ctrl+Return` | `center-column` |
| `Mod+Alt+T` | `toggle-column-tabbed-display` |
| `Mod+Space` | `switch-focus-between-floating-and-tiling` |
| `Mod+Shift+Space` | `move-window-to-floating` |
| `Mod+F1` | `show-hotkey-overlay` |

`Mod+Space` / `Mod+Shift+Space` treten an die Stelle des Special-Workspace-
Toggles, `Mod+F1` an die Stelle der Keybind-Listen (Abschnitt 10).

niris Default für `show-hotkey-overlay` wäre `Mod+Shift+Slash`. Auf dem
Schweizer Layout liegt `/` auf Shift+7 — der Bind würde also mit
`Mod+Shift+7` (Fenster auf Workspace 7) kollidieren. `Mod+F1` ist
layout-unabhängig.

### 7.5 Fenster & Session

| Taste | niri-Aktion | Änderung |
|---|---|---|
| `Mod+Q` | `close-window` | wie heute |
| `Mod+F` | `fullscreen-window` | wie heute |
| `Mod+Shift+F` | `toggle-window-floating` | wie heute |
| `Mod+Shift+C` | `quit` | wie heute |
| `Mod+S` | `screenshot` (niri-UI) | **nativ**, ersetzt `screenshootin` |
| `Mod+Ctrl+S` | `screenshot-screen` | ersetzt `hyprshot -m output` |
| `Mod+Shift+S` | `screenshot-window` | ersetzt `hyprshot -m window` |
| `Mod+Alt+C` | `spawn "wl-color-picker"` | ersetzt `hyprpicker` |
| `Mod+Shift+T` | `spawn-sh` Toggle auf Workspace `term` | ersetzt pyprland-Scratchpad |

`screenshot-path` wird auf `~/Pictures/ScreenShots/%Y-%m-%d %H-%M-%S.png`
gesetzt, damit die Ablage wie heute bleibt.

`Mod+Shift+T` kann kein reiner `focus-workspace`-Bind sein, weil ein Bind
nicht bedingt zurückspringen kann. Stattdessen ein `spawn-sh`-Einzeiler: er
liest `niri msg --json workspaces`, und je nachdem ob `term` gerade fokussiert
ist, ruft er `focus-workspace-previous` oder `focus-workspace term`. Der
Workspace `term` wird per `workspace "term"` deklariert und startet ein
Ghostty via `spawn-at-startup` mit passender `window-rule`.

### 7.6 Entfallende Binds

| Bind | Grund |
|---|---|
| `Mod+P` (`pseudo`) | Kein Gegenstück im Spalten-Modell |
| `Mod+Shift+I` (`togglesplit`) | dito; `toggle-column-tabbed-display` ist der nächste Verwandte |
| `Mod+Alt+F` (`workspaceopt allfloat`) | Kein Gegenstück |
| `Mod+Alt+Up/Down` (`swapwindow` vertikal) | niri kennt nur `swap-window-left/right` |
| `Mod+Ctrl+D` (`dock`) | `nwg-dock-hyprland` ist Hyprland-only; Noctalia hat einen eigenen Dock |
| `Mod+Shift+N` (`swaync-client -rs`) | swaync läuft bei `barChoice = "noctalia"` ohnehin nicht |
| `Mod+K` (`qs-keybinds`) | War bereits unerreichbar (Abschnitt 10); ersetzt durch `show-hotkey-overlay` |
| `Mod+Shift+K` (`list-keybinds`) | dito |
| `Mod+Alt+S` (`hyprshot -m region`) | Die niri-Screenshot-UI (`Mod+S`) startet ohnehin in der Regionsauswahl |
| `bindm` Maus-Move/Resize | Muss beim Aufsetzen geprüft werden (Abschnitt 11) |

## 8. Shell-Integration

Noctalia v5 bleibt vollständig: Bar, Dock, Launcher, Control-Center, Clipboard,
Notifications, Lockscreen, Idle-Daemon, Wallpaper. Keine Änderung an
`modules/upstream/home/noctalia.nix` nötig.

`exec-once` → `spawn-at-startup`:

```
wl-paste --type text  --watch cliphist store
wl-paste --type image --watch cliphist store
systemctl --user start hyprpolkitagent      # siehe Abschnitt 11
qs-wallpapers-restore                       # verzögert, wie heute
```

Entfallen gegenüber `exec-once.nix`:
- `dbus-update-activation-environment` und `systemctl --user import-environment`
  — `niri --session` importiert die Umgebung selbst. Genau deshalb setzt das
  nixpkgs-Modul `enableDefaultPath = false` auf der Unit.
- `qs -c overview` — Overview ist in niri eingebaut.
- Die `killall waybar/swaync`-Zeilen — unter niri existiert kein Waybar-Start.

`environment`-Block in der niri-Config übernimmt die relevanten Variablen aus
`env.nix` (`NIXOS_OZONE_WL`, `ELECTRON_OZONE_PLATFORM_HINT`, `MOZ_ENABLE_WAYLAND`,
`EDITOR`, `TERMINAL`, `XDG_TERMINAL_EMULATOR`). `XDG_CURRENT_DESKTOP` setzt niri
selbst auf `niri`; die Hyprland-Werte werden **nicht** übernommen.

`xwayland-satellite` wird über das HM-Modul installiert und in der Config per
`xwayland-satellite { path "..." }` verdrahtet.

## 9. GPU beim Docken

`modules/meo/hyprland-gpu-smart.nix` löst heute: externe Monitore hängen an der
NVIDIA-dGPU; rendert der Compositor auf der Intel-iGPU, wird jeder Frame über
PCIe kopiert (Cursor-Lag). Der Wrapper setzt `AQ_DRM_DEVICES` je nach
Docking-Zustand und lässt die dGPU im mobilen Betrieb in D3cold fallen.

niri hat kein `AQ_DRM_DEVICES`; die Renderer-Wahl sitzt in der Config unter
`debug { render-drm-device "..." }`. Da niri **kein `include`** kennt, kann der
Wrapper kein Fragment nachladen. Lösung über `NIRI_CONFIG` bzw. `-c`:

1. Karten-Nummern wie heute aus den PCI-Adressen auflösen
   (`0000:01:00.0` NVIDIA, `0000:00:02.0` Intel) — überlebt Kernel-Reordering.
2. Prüfen, ob ein Nicht-eDP-Output der NVIDIA-Karte `connected` ist.
3. `~/.config/niri/config.kdl` (HM-Symlink) nach
   `$XDG_RUNTIME_DIR/niri-config.kdl` kopieren und den passenden
   `debug { render-drm-device ... }`-Block anhängen.
4. `exec niri --session -c "$XDG_RUNTIME_DIR/niri-config.kdl"`.

Registriert als eigene Session „niri (Smart GPU)" über
`services.displayManager.sessionPackages`, analog zur bestehenden
„Hyprland (Smart GPU)". Der `debug`-Block darf deshalb **nicht** in der
HM-Config stehen, sonst entsteht er doppelt.

Damit ergeben sich vier Einträge im SDDM-Menü: niri, niri (Smart GPU),
Hyprland, Hyprland (Smart GPU). `defaultSession` zeigt auf „niri (Smart GPU)".

## 10. Befund: zwei tote Binds im Ist-Zustand

`hyprctl binds` auf der laufenden Session zeigt:

- `modmask 64` + Keysym `K` → „Keybinds Search Tool"
- `modmask 64` + Keysym `k` → „Focus Up (VI)"

Super+k ohne Shift erzeugt Keysym `k`, also feuert nur „Focus Up". **„Keybinds
Search Tool" ist unerreichbar.** Spiegelbildlich bei `modmask 65`
(Super+Shift): dort gewinnt „Legacy Keybinds Menu" (Keysym `K`) und **„Move Up
(VI)" ist tot**.

In niri kann das nicht wiederkehren: doppelte Binds lässt `niri validate` nicht
durch, und die HM-`checkPhase` bricht den Build ab. Die Migration räumt beides
auf — vertikales Bewegen liegt eindeutig auf `Mod+Shift+K`, die Keybind-Übersicht
auf dem nativen `show-hotkey-overlay` (`Mod+F1`).

## 11. Offene Punkte

1. **Maus-Binds** (`Mod+LMB` move, `Mod+RMB` resize): niris Unterstützung für
   Maus-Drag-Bindings ist nicht verifiziert. Beim Aufsetzen prüfen; falls nicht
   konfigurierbar, greift niris eingebautes Verhalten für Floating-Fenster.
2. **`hyprpolkitagent`**: läuft als systemd-User-Unit und sollte
   compositor-unabhängig sein. Noctalia bringt mit `shell.polkit_agent = true`
   einen eigenen mit — beim Aufsetzen prüfen, ob der Hyprland-Agent überhaupt
   noch nötig ist, sonst entfällt die Startup-Zeile.
3. **`Mod+Shift+W` ist im Ist-Zustand doppelt belegt** (Noctalia-Wallpaper-Panel
   und `qs-wallpapers-apply`). Für niri wird das Noctalia-Panel gewählt; der
   zweite Bind entfällt.
4. **`windowrules.nix`**: nur eine Teilmenge wird portiert (Floating-Dialoge,
   Bild-in-Bild, `block-out-from` für sensible Fenster). Der Rest wandert
   nach Bedarf nach.
5. **Stylix** hat kein niri-Target. Farben kommen weiterhin über Noctalia, GTK
   und Qt; `focus-ring`-Farben werden aus der Stylix-Palette gesetzt.
6. **`Mod+Shift+1..0` auf CH-Layout**: niri löst Binds über Keysyms auf. Auf
   dem Schweizer Layout erzeugt Shift+1 ein `+`, Shift+2 ein `"` usw. Ob
   `Mod+Shift+1` trotzdem greift (Hyprland kann das heute), ist nicht
   verifiziert und lässt sich nur in einer laufenden Session prüfen, nicht per
   `niri validate`. Fallback, falls nicht: die Shift-Level-Keysyms binden
   (`Mod+plus`, `Mod+quotedbl`, `Mod+asterisk`, …). Das ist der erste Punkt,
   den der erste Login prüfen muss.
7. **`travel-mode`-Script** (`modules/meo/scripts/travel-mode.nix`) referenziert
   Hyprland — beim Aufsetzen prüfen und ggf. compositor-aware machen.

## 12. Verifikation

**Vor dem ersten Login**
- `nh os build --hostname meo` — die HM-`checkPhase` jagt die generierte KDL
  durch `niri validate`; ein Config-Fehler bricht den Build.
- `nh os build --hostname meo-work` — Regressionsschutz für den zweiten Host
  (Anti-Pattern-Regel aus `CLAUDE.md`).

**Beim ersten Login** (Hyprland bleibt im selben SDDM-Menü als Rückweg)
1. Beide Monitore in korrekter Größe, Position und Skalierung.
2. Eine XWayland-App (Affinity oder Bambu Studio) startet und ist scharf —
   das ist der eigentliche Test für Punkt 2 aus Abschnitt 1.
3. Noctalia-Bar, Dock, Launcher (`Mod+D`), Clipboard (`Mod+V`) reagieren.
4. `Mod+Alt+L` sperrt und suspendiert; Resume kommt sauber zurück.
5. Undock/Redock: `niri-gpu-smart` wählt beim nächsten Session-Start die
   richtige Karte.
6. Akku-Switcher: Netzteil ziehen, `niri msg outputs` zeigt eDP-1 auf 60 Hz.
