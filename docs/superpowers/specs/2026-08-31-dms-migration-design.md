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

**Das Nix-Modul schreibt die Konfiguration selbst.** `distro/nix/home.nix`
deklariert (zusätzlich zu den Schaltern in `options.nix` — die Optionen sind
über zwei Dateien verteilt):

```
programs.dank-material-shell.settings          -> ~/.config/DankMaterialShell/settings.json
programs.dank-material-shell.clipboardSettings -> ~/.config/DankMaterialShell/clsettings.json
programs.dank-material-shell.session           -> ~/.local/state/DankMaterialShell/session.json
programs.dank-material-shell.managePluginSettings
```

Alle per `jsonFormat`, jeweils mit `lib.mkIf (cfg.settings != { })`. Eine
Teilmenge ist damit ausdrücklich vorgesehen; ein leeres Attrset erzeugt gar
keine Datei. Die Konfiguration läuft also über das Modul, nicht an ihm vorbei.

**Stylix hat ein eigenes DMS-Ziel, und es ist bereits aktiv.**
`stylix.targets.dank-material-shell.enable` steht auf `true`. Das Ziel setzt
`fontFamily`, `monoFontFamily`, `popupTransparency`, `dockTransparency`,
`session.wallpaperPath` sowie einen vollständigen `customThemeFile` mit 18 aus
der base16-Palette abgeleiteten Farben. Das Theming ist damit ohne eigenen Code
erledigt.

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
| 2 | Konfiguration über `programs.dank-material-shell.settings` | das Modul schreibt `settings.json` selbst (`distro/nix/home.nix`); eine Teilmenge ist per `mkIf (cfg.settings != {})` ausdrücklich vorgesehen |
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

`noctalia.nix` enthält zwei Dienste, die mit dem Shell nichts zu tun haben und
beim Umschalten mit verschwinden würden. Beide brauchen **keine** Behandlung —
aus unterschiedlichen Gründen, beide am 2026-08-31 auf der Maschine gemessen:

**`hyprland-monitor-hotplug`** läuft unter niri ohnehin nicht:

```
Active: inactive (dead) (Result: exec-condition)
Process: ExecCondition=…/hotplug-only-without-niri (code=exited, status=1/FAILURE)
```

Der Wächter aus `modules/meo/niri/hyprland-compat.nix` hält ihn seit der
niri-Migration ab. Seine Aufgabe — das Monitorlayout nach einem Hotplug
wiederherstellen — ist eine Hyprland-Krücke; niri setzt die Ausgänge
deklarativ über `modules/meo/niri/outputs.nix` und braucht sie nicht. Es geht
also nichts verloren, was nicht schon stillsteht.

**`bt-audio-monitor`** läuft zwar (`active (running)`), hat aber laut Nutzer nie
zuverlässig funktioniert und wird bewusst **fallengelassen**. Er verschwindet
mit dem Gate. Die Derivation `modules/meo/scripts/bt-audio-monitor.nix` bleibt
zunächst ungenutzt im Repo liegen; ihr Entfernen ist ein eigener, optionaler
Aufräumschritt und keine Voraussetzung.

### 5.2 Die Einstellungsdatei

Neues `modules/meo/dms/settings.nix` setzt `programs.dank-material-shell.settings`.
Der Aufbau folgt `modules/upstream/home/noctalia.nix`: nur die Werte, die beim
ersten Start stimmen müssen; alles Übrige bleibt bei DMS' Vorgaben und bei dem,
was Stylix beisteuert.

```nix
programs.dank-material-shell.settings = {
  fadeToDpmsEnabled = vars.dmsScreenOff or false;   # eDP-Sperre, siehe 5.3
  fadeToDpmsGracePeriod = 5;
  acLockTimeout = 600;                              # wie Noctalia heute
  batteryLockTimeout = 600;
};
```

Farben, Schriften, Transparenz und Wallpaper stehen bewusst **nicht** hier —
die setzt Stylix über sein DMS-Ziel (siehe 5.4).

### 5.3 Die eDP-Sperre

`hosts/meo/variables.nix` hat heute `idleScreenOff = false` mit der Begründung,
dass DPMS-off→on auf dem OLED die i915-Pipe aufhängt (nur Reboot hilft; dazu
gehören die `i915.enable_{psr,fbc,dc}=0` in den kernelParams).

Diese Sperre wird **nicht** übersetzt, sondern übernommen: `dmsScreenOff`
kommt aus derselben Datei und setzt `fadeToDpmsEnabled`. Damit bleibt die
Eigenschaft erhalten, die heute den Schaden verhindert — die Maschine *kann*
nicht in den Zustand geraten, statt dass es an einem Häkchen hängt.

### 5.4 Theming

**Nichts zu tun.** `stylix.targets.dank-material-shell.enable` steht in dieser
Konfiguration bereits auf `true`. Sobald DMS' Modul importiert ist, setzt
Stylix von selbst:

- `settings.fontFamily`, `settings.monoFontFamily` aus den Stylix-Schriften,
- `settings.popupTransparency`, `settings.dockTransparency` aus `stylix.opacity`,
- `session.wallpaperPath` aus `stylix.image`,
- `settings.currentThemeName = "custom"` und einen `customThemeFile` mit 18 aus
  der base16-Palette abgeleiteten Farben.

Das deckt mehr ab als Stylix' Noctalia-Ziel. Ein eigenes Themenmodul wäre
doppelte Arbeit und würde mit Stylix um dieselben Schlüssel streiten — die
DMS-Einstellungen in 5.2 setzen deshalb bewusst **keine** Farben, Schriften
oder Transparenzen.

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
| 1 | Akzeptiert DMS eine unvollständige `settings.json`? | **Entschieden: ja.** Das Modul schreibt sie über `jsonFormat` mit `lib.mkIf (cfg.settings != { })` — eine Teilmenge ist der vorgesehene Fall, ein leeres Attrset erzeugt gar keine Datei |
| 2 | Struktur der `customThemeFile` für Stylix | **Entfällt.** Stylix' DMS-Ziel erzeugt die Datei selbst; die Struktur ist dort festgelegt |
| 3 | IPC-Name für das Wallpaper-Panel (`Mod+Shift+W`) | `dms ipc call` gegen das Paket abfragen |
| 4 | Kollidiert DMS' Dock mit der Dashboard-Spalte? | erst im Betrieb entscheidbar |
| 5 | `modules/meo/niri/hyprland-compat.nix` wird zum toten Code | **Entschieden: ja.** Seine einzige Aufgabe ist, `hyprland-monitor-hotplug` unter niri zu überspringen. Wird Noctalia stillgelegt, existiert dieser Dienst gar nicht mehr — der Wächter bewacht dann nichts. Die Datei wird im Zuge der Umsetzung entfernt und aus `modules/meo/niri/default.nix` ausgetragen. Konsequenz für den Rückweg: schaltet man auf `barChoice = "noctalia"` zurück, kommt der Hotplug-Dienst ungewächtert wieder und würde unter niri als `failed` parken. Das ist hinnehmbar (kosmetisch, kein Funktionsverlust), muss aber im Plan als Nebenwirkung stehen |

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
