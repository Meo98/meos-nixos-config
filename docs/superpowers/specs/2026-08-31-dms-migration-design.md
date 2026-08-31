# Shell-Wechsel Noctalia → DankMaterialShell (Host `meo`) — Design-Spec

Datum: 2026-08-31
Status: entworfen, nicht umgesetzt
Teilprojekt B von dreien. A (meo-work auf niri) ist umgesetzt, siehe
`2026-08-31-meo-work-niri-migration-design.md`. C (SDDM-Theme → dank-greeter)
folgt später.

## 1. Problem & Kontext

Der Wunsch ist ein Shell-Wechsel auf DankMaterialShell — **nicht**, weil an
Noctalia etwas kaputt wäre, sondern weil DMS eine dedizierte niri-Integration
mitbringt und seine Plugins reproduzierbar verwaltet.

Beide Punkte sind geprüft und treffen zu:

- DMS' Flake liefert neben dem Haupt-Modul ein eigenes `homeModules.niri`, das
  niri-Config-Dateien erzeugt und einbindet.
- DMS' HM-Modul nimmt Plugins als `attrsOf { enable; src; settings; }` — `src`
  ist ein Nix-Paket, also ein gepinnter Commit mit Hash. Noctalia zieht seine
  Plugins dagegen **zur Laufzeit per git** nach (am 2026-08-31 im Journal
  beobachtet: `[plugins.git] git … fetch origin`, `updated source 'official'`).
  Der Plugin-Stand hängt dort davon ab, wann zuletzt gefetcht wurde.

**Umkehrbarkeit ist ausdrückliche Anforderung.** Die Noctalia-Konfiguration
bleibt vollständig erhalten und wird nur stillgelegt; ein Wort in
`variables.nix` plus `fr` schaltet zurück.

## 2. Ziele / Nicht-Ziele

**Ziele**

- `meo` startet nach dem nächsten `fr` in DMS statt Noctalia.
- Die Konfiguration bleibt **deklarativ** — inklusive der sicherheitsrelevanten
  eDP-Sperre.
- Noctalia bleibt vollständig konfiguriert im Repo, nur inaktiv.
- Die neun Noctalia-IPC-Binds bekommen DMS-Gegenstücke, damit der Shell
  vollständig über die Tastatur bedienbar ist.

**Nicht-Ziele**

- Kein `meo-work`. Der Host läuft noch auf Hyprland (Teilprojekt A ist committet,
  aber dort nicht angewendet), und der Nutzer hat gerade keinen Zugriff. Der
  Schalter ist dort später eine Zeile.
- Keine Änderung an der Dashboard-Spalte, bis geklärt ist, ob DMS' eigenes Dock
  mit ihr kollidiert.
- Kein `dank-greeter` (Teilprojekt C).
- Kein Entfernen von Noctalia.

## 3. Verifizierte Grundlagen

Alles am 2026-08-31 aus dem DMS-Quelltext bzw. der laufenden Maschine
gemessen, nicht aus Dokumentation übernommen.

**DMS unterstützt eine schreibgeschützte Konfiguration ausdrücklich.**
`quickshell/Common/SettingsData.qml` prüft zur Laufzeit die Schreibbarkeit und
schaltet sauber um:

```qml
function _onWritableCheckComplete(writable) {
    _isReadOnly = !writable;
    if (_isReadOnly) {
        _hasUnsavedChanges = _checkForUnsavedChanges();
        log.info("settings.json is now read-only");
    }
}
```

Das ist ein vorgesehener Betriebsmodus, kein Fehlerpfad. Eine Datei aus dem
Nix-Store ist schreibgeschützt — DMS respektiert sie.

**Pfad und Nachladen.** `settingsFile.path` ist
`StandardPaths.ConfigLocation + "/DankMaterialShell/settings.json"`, also
`~/.config/DankMaterialShell/settings.json`. Die Datei wird beobachtet und über
einen Debounce neu geladen (`settingsFile.reload()`). Ein `fr`, das den Symlink
tauscht, wirkt damit ohne Neustart des Shells.

**Die sicherheitskritischen Schlüssel sind normale Einstellungen:**

```
fadeToDpmsEnabled       (bool)   Bildschirm nach Idle abschalten
fadeToDpmsGracePeriod   (int)
acLockTimeout           (int)    0 = aus
batteryLockTimeout      (int)
```

**Das Nix-Modul deckt nur einen kleinen Teil ab** — elf Optionen (`enable`,
`package`, `systemd.*`, sechs Funktionsschalter, `quickshell.package`,
`plugins`) und schreibt **keine** Einstellungsdatei. Die Konfiguration läuft
deshalb nicht über das Modul, sondern über die Datei.

**Der Include-Mechanismus zielt auf niri-flake.** `distro/nix/niri.nix` setzt
`xdg.configFile.niri-config.target = lib.mkForce "niri/hm.kdl"`. Dieser
Attributname stammt aus niri-flake; das hier verwendete nixpkgs-HM-Modul nennt
seinen Eintrag `"niri/config.kdl"` (gemessen). Der Mechanismus muss deshalb
nachgebaut werden — siehe 5.5.

**niri-Includes sind positional.** Laut niri-Dokumentation überschreiben
spätere Includes frühere, und Fensterregeln werden an der Include-Zeile
eingefügt. `includes.override = false` stellt DMS' Dateien **vor** die eigene
Config; die eigene gewinnt damit.

## 4. Getroffene Entscheidungen

| # | Entscheidung | Begründung |
|---|---|---|
| 1 | Schalter über das vorhandene `barChoice`, Wert `"dms"` | die Weiche existiert bereits für `noctalia`/`waybar`; kein neues Konzept |
| 2 | `settings.json` aus Nix statt über Modul-Optionen | das Modul kann es nicht, die Anwendung schon — und sie ist auf Schreibschutz vorbereitet |
| 3 | eDP-Sperre aus `variables.nix`, nicht fest verdrahtet | gleiche Aufteilung wie `idleScreenOff` heute; meo-work braucht später den anderen Wert |
| 4 | `includes.override = false` | DMS als Basis, die gewachsene niri-Config gewinnt — Spaltenbreiten, Zentrierung, Dashboard-Regel und CH-Binds bleiben unangetastet |
| 5 | Nur `meo` | meo-work ist nicht erreichbar und nicht auf niri |
| 6 | Noctalia bleibt vollständig | Umkehrbarkeit ist Anforderung, nicht Zugabe |

## 5. Architektur

### 5.1 Der Schalter

`hosts/meo/variables.nix` bekommt `barChoice = "dms";` (heute `"noctalia"`).

Ein neues `modules/meo/dms/default.nix` aktiviert sich nur bei diesem Wert;
`modules/upstream/home/noctalia.nix` wird umgekehrt übersprungen. Die
Umschaltung ist damit ein Wort.

**Wichtig:** `noctalia.nix` enthält zwei Dienste, die mit dem Shell nichts zu
tun haben und in **beiden** Fällen laufen müssen —
`hyprland-monitor-hotplug` und `bt-audio-monitor` (Bluetooth-Audio-Umschaltung).
Sie wandern vor dem Gate in ein eigenes Modul, sonst verschwinden sie beim
Umschalten still mit.

### 5.2 Die Einstellungsdatei

Neues `modules/meo/dms/settings.nix` erzeugt `settings.json` aus einem
Nix-Attrset und legt sie über `xdg.configFile` ab. Der Aufbau folgt
`modules/upstream/home/noctalia.nix`: nur die Werte, die beim ersten Start
stimmen müssen; alles Übrige bleibt bei DMS' Vorgaben.

Zu setzen sind mindestens:

```nix
{
  fadeToDpmsEnabled = vars.dmsScreenOff or false;   # eDP-Sperre, siehe 5.3
  fadeToDpmsGracePeriod = 5;
  acLockTimeout = 600;                              # wie Noctalia heute
  batteryLockTimeout = 600;
  currentThemeName = …;                             # Stylix, siehe 5.4
}
```

**Offen:** ob DMS eine **unvollständige** `settings.json` akzeptiert und die
fehlenden Werte aus den QML-Vorgaben ergänzt, oder ob es eine vollständige
Datei erwartet. Der Code deutet auf Ersteres (jede Einstellung ist eine
`property` mit Vorgabewert), ist aber vor der Umsetzung zu prüfen — siehe
Abschnitt 7.

### 5.3 Die eDP-Sperre

`hosts/meo/variables.nix` hat heute `idleScreenOff = false` mit der Begründung,
dass DPMS-off→on auf dem OLED die i915-Pipe aufhängt (nur Reboot hilft; dazu
gehören die `i915.enable_{psr,fbc,dc}=0` in den kernelParams).

Diese Sperre wird **nicht** übersetzt, sondern übernommen: `dmsScreenOff`
kommt aus derselben Datei und setzt `fadeToDpmsEnabled`. Damit bleibt die
Eigenschaft erhalten, die heute den Schaden verhindert — die Maschine *kann*
nicht in den Zustand geraten, statt dass es an einem Häkchen hängt.

### 5.4 Theming

Stylix setzt bei Noctalia heute `theme.mode`, `theme.source` und
`shell.font_family` (mit `mkForce` gegen Konflikte). DMS kennt
`currentThemeName`, `currentThemeCategory` und `customThemeFile`.

Der Weg führt über `customThemeFile`: eine aus der Stylix-Palette erzeugte
Themendatei, ebenfalls im Store. Alternativ deckt DMS' Modul-Option
`enableDynamicTheming` einen Teil ab — welcher Weg trägt, ist in der Umsetzung
zu entscheiden, sobald die Themendatei-Struktur bekannt ist.

### 5.5 Die niri-Integration

DMS' `homeModules.niri` mit `includes.override = false`, also DMS-Dateien
zuerst, die eigene Config zuletzt.

Der Einbindungs-Trick des Moduls greift hier **nicht**, weil er den
niri-flake-Attributnamen `niri-config` per `mkForce` umbiegt. Nachbau für das
nixpkgs-Modul:

1. den vorhandenen Eintrag `"niri/config.kdl"` auf `niri/hm.kdl` umleiten,
2. eine eigene `niri/config.kdl` schreiben, die erst DMS' Dateien und dann
   `hm.kdl` per `include optional=true` einbindet.

`optional=true` gibt es seit niri 26.04 (hier im Einsatz); ein fehlendes
Teilstück ist damit eine Warnung statt eines Fehlers.

`enableKeybinds` bleibt **aus**. DMS' Vorschlag belegt unter anderem `Mod+Space`,
`Mod+V`, `Mod+X`, `Mod+M` und `Mod+Comma` — alles Tasten, die hier bereits
anders belegt sind (`Mod+Space` schaltet zwischen Floating und Tiling,
`Mod+Comma` nimmt ein Fenster in die Spalte auf). Die Binds werden stattdessen
von Hand gesetzt, siehe 5.6.

### 5.6 Die neun Binds

`modules/meo/niri/binds-apps.nix` ruft an neun Stellen `noctalia msg …`. Sie
werden hinter demselben Gate auf `dms ipc call …` umgestellt:

| Taste | heute | künftig |
|---|---|---|
| `Mod+D`, `Mod+Shift+Return` | `panel-toggle launcher` | `spotlight toggle` |
| `Mod+V` | `panel-toggle clipboard` | `clipboard toggle` |
| `Mod+M` | `panel-toggle control-center notifications` | `notifications toggle` |
| `Mod+C` | `panel-toggle control-center` | `control-center toggle` |
| `Mod+X` | `panel-toggle session` | `powermenu toggle` |
| `Mod+Shift+W` | `panel-toggle wallpaper` | zu ermitteln |
| `Mod+Alt+P`, `Mod+Shift+Comma` | `settings-toggle` | `settings toggle` |
| `Mod+Alt+L` | `loginctl lock-session && …` | unverändert (compositor-neutral) |

Ebenso `vol-smart` und `bright-smart` auf den Multimedia-Tasten: die rufen
heute nicht Noctalia, sondern eigene Skripte — sie bleiben unverändert.

### 5.7 Plugins

Über `programs.dank-material-shell.plugins`, je Plugin ein `src` als
`fetchFromGitHub` mit Revision und Hash. Welche Plugins, entscheidet der Nutzer
nach dem ersten Start über `dms plugins search`; der Spec legt sich nicht fest.

## 6. Was unverändert bleibt

- **Die Dashboard-Spalte** (`modules/meo/niri/dashboard.nix` und ihre Regel in
  `rules.nix`). Ob DMS' Dock mit ihr kollidiert, entscheidet der Alltag.
- **`lock-before-sleep`** — System-Unit, compositor- und shell-neutral.
- **hypridle** — läuft unter niri ohnehin nicht.
- **Die niri-Konfiguration** — Layout, Regeln, Navigation, Ausgänge.
- **`niri-term-toggle`, `keymap-popup`, `vol-smart`, `bright-smart`.**

## 7. Offene Punkte

| # | Punkt | Klärung |
|---|---|---|
| 1 | Akzeptiert DMS eine unvollständige `settings.json`? | vor der Umsetzung mit einer Minimaldatei gegen das Paket prüfen |
| 2 | Struktur der `customThemeFile` für Stylix | aus dem DMS-Quelltext ableiten; sonst `enableDynamicTheming` als Rückfall |
| 3 | IPC-Name für das Wallpaper-Panel (`Mod+Shift+W`) | `dms ipc call` gegen das Paket abfragen |
| 4 | Kollidiert DMS' Dock mit der Dashboard-Spalte? | erst im Betrieb entscheidbar |
| 5 | Wird `modules/meo/niri/hyprland-compat.nix` zum toten Verweis? | sein Wächter schützt `hyprland-monitor-hotplug`, das aus `noctalia.nix` stammt; nach 5.1 wandert der Dienst in ein eigenes Modul und bleibt bestehen — dann bleibt der Wächter gültig |

Punkt 1 ist der einzige, der die Architektur umwerfen könnte: verlangt DMS eine
vollständige Datei, wird `settings.nix` deutlich grösser und muss bei jedem
DMS-Update gegen neue Schlüssel geprüft werden. Deshalb steht er zuerst im Plan.

## 8. Verifikation

1. `nix build` für **beide** Hosts vor jedem Commit.
2. **Store-Pfad von `meo-work` muss unverändert bleiben** — dieser Umbau
   betrifft nur `meo`. Bewegt er sich, wurde versehentlich etwas Gemeinsames
   angefasst.
3. Die erzeugte `settings.json` gegen die Erwartung prüfen, insbesondere
   `fadeToDpmsEnabled = false`.
4. Die erzeugte `niri/config.kdl` muss die Include-Zeilen in der richtigen
   Reihenfolge tragen (DMS zuerst, `hm.kdl` zuletzt) und `niri validate`
   bestehen — Letzteres läuft automatisch in der `checkPhase`.
5. Nach dem `fr`: Leiste da, die neun Tasten wirken, Sperrbildschirm kommt,
   Bildschirm schaltet **nicht** ab.

## 9. Rückweg

`barChoice = "noctalia"` in `hosts/meo/variables.nix`, dann `fr`. Noctalia ist
vollständig konfiguriert und unverändert; es fehlt nur die Aktivierung.

Bleibt DMS dauerhaft, kann Noctalia später entfernt werden — das ist dann ein
eigener, kleiner Aufräumschritt und keine Voraussetzung.
