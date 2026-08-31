# Shell-Wechsel auf DankMaterialShell (Host `meo`) — Implementierungsplan

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte verwenden Checkbox-Syntax (`- [ ]`) zur Nachverfolgung.

**Ziel:** Host `meo` startet in DankMaterialShell statt Noctalia, mit deklarativer Konfiguration, und lässt sich mit einem Wort in `variables.nix` zurückschalten.

**Architektur:** Die vorhandene `barChoice`-Weiche wird von zwei auf drei Werte erweitert. Ein neues Modul `modules/meo/dms/` bringt Paket, systemd-Unit und eine aus Nix erzeugte `settings.json` mit — DMS unterstützt schreibgeschützte Konfiguration ausdrücklich. Noctalia bleibt vollständig konfiguriert und wird nur nicht mehr importiert.

**Tech-Stack:** Nix-Flakes, home-manager, niri 26.04, DankMaterialShell (Quickshell + Go), KDL- und JSON-Generierung aus Nix.

**Spec:** `docs/superpowers/specs/2026-08-31-dms-migration-design.md`

## Globale Randbedingungen

- **Niemals** `fr`, `nh os switch`, `nixos-rebuild`, `systemctl` oder `loginctl` ausführen. Rebuilds macht ausschliesslich der Nutzer.
- **Niemals** ohne Rückfrage pushen oder mergen. Commits sind erlaubt.
- **`modules/meo/default.nix` und `modules/meo/scripts.nix` sind tabu.**
- **`modules/upstream/` wird in diesem Plan an genau zwei Stellen angefasst** (Aufgabe 3), beide Male mit `# MODIFIED`-Kommentar und beide Male so, dass sie für beide Hosts gelten. Jede weitere Berührung von `modules/upstream/` ist ein Planfehler und zu melden.
- Jede Prüfung läuft über `nix build --no-link --print-out-paths '.#nixosConfigurations.<host>.config.system.build.toplevel'`.
- **Baseline-Store-Pfade vor Beginn** (gemessen 2026-08-31):
  - `meo` → `/nix/store/5cliik0gn5wf3mjn579vj4q8yp6w2y09-nixos-system-meo-26.11.20260822.2c423e0`
  - `meo-work` → `/nix/store/ngvh42fb3nqmb7wazpdrvf9l0k028n2h-nixos-system-meo-work-26.11.20260822.2c423e0`
- **`meo-work` darf sich in diesem gesamten Plan NIE bewegen.** Dieser Umbau betrifft nur `meo`. Ein wandernder meo-work-Pfad bedeutet, dass versehentlich etwas Gemeinsames verändert wurde — melden, nicht hinnehmen.
- Bis einschliesslich Aufgabe 7 bleibt `barChoice = "noctalia"`; **auch `meo` darf sich bis dahin nicht bewegen.** Erst Aufgabe 8 schaltet um.
- Jede Aufgabe endet mit einem Commit. Commit-Nachrichten auf Deutsch.
- Kommentare im Code auf Deutsch, ohne Umlaute.
- Builds dauern; Timeouts grosszügig (600000 ms). Bekannte harmlose Eval-Warnungen von nix-index-database und hyprland auf stderr ignorieren.

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `flake.nix` | neuer Input `dank-material-shell` |
| `modules/upstream/home/default.nix` | Weiche dreiwertig (Aufgabe 3) |
| `modules/upstream/core/packages.nix` | Noctalia-Pakete nur noch bei `"noctalia"` (Aufgabe 3) |
| `modules/meo/dms/default.nix` | Modul-Einstieg: Paket, systemd-Unit, Importe |
| `modules/meo/dms/settings.nix` | erzeugt `settings.json` aus Nix |
| `modules/meo/dms/niri.nix` | Include-Nachbau + `homeModules.niri` |
| `modules/meo/dms/theme.nix` | Stylix-Farben nach DMS |
| `modules/meo/niri/binds-apps.nix` | neun Binds, geschaltet vom Gate |
| `hosts/meo/variables.nix` | `barChoice`, `dmsScreenOff` |

---

### Aufgabe 1: Flake-Input und Paket

Nur den Input hinzufügen und nachweisen, dass das Paket baut. Noch keine Host-Änderung.

**Dateien:**
- Ändern: `flake.nix`
- Ändern: `flake.lock` (durch `nix flake update`)

**Schnittstellen:**
- Erzeugt: `inputs.dank-material-shell` mit den Ausgängen
  `homeModules.dank-material-shell`, `homeModules.niri`,
  `nixosModules.dank-material-shell`, `packages.<system>.dms-shell`.
  Aufgabe 4 und 5 benutzen sie.

- [ ] **Schritt 1: Input eintragen**

In `flake.nix` bei den übrigen Inputs einfügen, im Stil des `noctalia`-Blocks daneben:

```nix
    # DankMaterialShell — Shell-Alternative zu Noctalia, gated ueber
    # barChoice in hosts/<host>/variables.nix.
    # Spec: docs/superpowers/specs/2026-08-31-dms-migration-design.md
    #
    # Wie bei noctalia bewusst auf einen Release-Tag gepinnt statt auf
    # master-HEAD: Releases sind getestet, master ist Lotterie.
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Schritt 2: Lock erzeugen**

```bash
cd /home/meo/nixos-config
nix flake update dank-material-shell
```

- [ ] **Schritt 3: Prüfen, welche Ausgänge der Input wirklich hat**

```bash
cd /home/meo/nixos-config
nix flake show github:AvengeMedia/DankMaterialShell --json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k in ('homeModules','nixosModules'):
    print(k, list(d.get(k,{}).keys()))
print('packages', list(d.get('packages',{}).get('x86_64-linux',{}).keys()))"
```

Erwartet: `homeModules` enthält `dank-material-shell` und `niri`;
`packages` enthält `dms-shell`.

Weicht das ab, **nicht raten** — die tatsächlichen Namen notieren und in den folgenden Aufgaben verwenden; sie sind die Schnittstelle.

- [ ] **Schritt 4: Das Paket bauen**

```bash
cd /home/meo/nixos-config
nix build --no-link --print-out-paths '.#nixosConfigurations.meo.pkgs.hello' >/dev/null 2>&1
nix build --no-link --print-out-paths 'github:AvengeMedia/DankMaterialShell#dms-shell'
```

Erwartet: ein Store-Pfad. Das kann lange dauern (Go + Quickshell).

- [ ] **Schritt 5: Beide Hosts prüfen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: **beide unverändert** gegenüber der Baseline. Ein Flake-Input, den niemand benutzt, darf das erzeugte System nicht verändern.

- [ ] **Schritt 6: Commit**

```bash
cd /home/meo/nixos-config
git add flake.nix flake.lock
git commit -m "dms: Flake-Input hinzufuegen (noch ungenutzt)

Bringt homeModules.dank-material-shell, homeModules.niri und das Paket
dms-shell ins Repo. Wird von niemandem importiert, beide Store-Pfade
sind daher unveraendert."
```

---

### Aufgabe 2: Klären, ob DMS eine unvollständige `settings.json` akzeptiert

Das ist offener Punkt 1 des Specs und die einzige Annahme, die den Entwurf umwerfen kann. Deshalb **vor** allem anderen.

Erwartung aus dem Quelltext: jede Einstellung ist eine QML-`property` mit Vorgabewert, eine Teilmenge sollte also genügen. Zu belegen, nicht zu glauben.

**Dateien:**
- Erstellt: keine (Erkenntnis-Aufgabe)
- Bericht: die Antwort wandert als Kommentar in `modules/meo/dms/settings.nix` (Aufgabe 4)

- [ ] **Schritt 1: Den Ladepfad im Quelltext lesen**

```bash
cd /tmp/claude-1000/-home-meo/90fa53bf-bf51-4a6d-8b74-fdd6a02a882a/scratchpad
curl -sSL --max-time 25 "https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/master/quickshell/Common/SettingsData.qml" -o sd.qml
sed -n '1665,1700p' sd.qml
```

Gesucht: die Stelle, die `settingsFile.text()` parst und die Werte übernimmt. Entscheidend ist, ob sie über die **vorhandenen Schlüssel der Datei** iteriert (dann genügt eine Teilmenge) oder über **alle bekannten Properties** und fehlende auf `undefined` setzt (dann nicht).

- [ ] **Schritt 2: Den Store-Mechanismus ansehen**

```bash
cd /tmp/claude-1000/-home-meo/90fa53bf-bf51-4a6d-8b74-fdd6a02a882a/scratchpad
curl -sSL --max-time 25 "https://api.github.com/repos/AvengeMedia/DankMaterialShell/contents/quickshell/Common" 2>/dev/null | grep -oE '"name": "[^"]*Store[^"]*"'
```

Die gefundene Datei holen und ihre `fromJson`-Funktion lesen.

- [ ] **Schritt 3: Praktisch gegenprüfen, wenn möglich**

niri kann verschachtelt in einem Fenster laufen. Damit lässt sich DMS mit einer Minimal-Konfiguration starten, ohne die laufende Sitzung anzufassen:

```bash
D=$(mktemp -d)
mkdir -p "$D/DankMaterialShell"
printf '{"fadeToDpmsEnabled": false}\n' > "$D/DankMaterialShell/settings.json"
dms=$(nix build --no-link --print-out-paths 'github:AvengeMedia/DankMaterialShell#dms-shell')
XDG_CONFIG_HOME="$D" timeout 25 "$dms"/bin/dms run 2>&1 | head -40
```

Erwartet bei gutem Ausgang: DMS startet, meldet sinngemäss `settings.json is now read-only` **nicht** (die Datei ist hier schreibbar) und wirft keine Fehler über fehlende Schlüssel.

Scheitert der Start mangels Wayland-Display, ist das **kein** negatives Ergebnis — dann zählt allein die Quelltext-Analyse aus Schritt 1 und 2.

- [ ] **Schritt 4: Ergebnis festhalten**

Kein Commit (nichts geändert). Das Ergebnis in den Bericht schreiben, in einem Satz:

- **Teilmenge genügt** → weiter wie geplant.
- **Vollständige Datei nötig** → **melden und anhalten.** Dann muss `settings.nix` alle Schlüssel führen, und der Spec braucht eine Überarbeitung; das ist keine Entscheidung, die in dieser Aufgabe getroffen wird.

---

### Aufgabe 3: Die `barChoice`-Weiche dreiwertig machen

Heute ist die Weiche zweiwertig: `"noctalia"` oder — in **jedem** anderen Fall — waybar. Ein `barChoice = "dms"` würde also waybar laden. Das wird repariert, bevor der Wert überhaupt vergeben wird.

**Dies ist die einzige Aufgabe, die `modules/upstream/` anfasst.** Zwei Stellen, beide mit `# MODIFIED`-Kommentar, beide für beide Hosts gültig.

**Dateien:**
- Ändern: `modules/upstream/home/default.nix` (Zeilen 16–20, `barModule`)
- Ändern: `modules/upstream/core/packages.nix` (Zeilen 8–10, `noctaliaPkgs`)
- Erstellt: `modules/meo/dms/default.nix` (zunächst ein leeres Gerüst)

**Schnittstellen:**
- Erzeugt: `barChoice = "dms"` wählt `modules/meo/dms/default.nix`.
  Aufgabe 4 füllt diese Datei.

- [ ] **Schritt 1: Leeres Gerüst anlegen**

`modules/meo/dms/default.nix`:

```nix
# DankMaterialShell — Einstieg. Wird von modules/upstream/home/default.nix
# importiert, wenn barChoice = "dms" in hosts/<host>/variables.nix steht.
#
# Spec: docs/superpowers/specs/2026-08-31-dms-migration-design.md
#
# Noch leer: Aufgabe 3 baut nur die Weiche, Aufgabe 4 fuellt das Modul.
{...}: {
}
```

- [ ] **Schritt 2: Die Weiche in `modules/upstream/home/default.nix`**

Ersetze:

```nix
  # Select bar module based on barChoice
  barModule =
    if barChoice == "noctalia"
    then ./noctalia.nix
    else waybarChoice;
```

durch:

```nix
  # Select bar module based on barChoice
  #
  # MODIFIED 2026-08-31: dritter Wert "dms" (DankMaterialShell). Vorher war
  # die Weiche zweiwertig und fiel bei JEDEM anderen Wert auf waybar zurueck —
  # ein barChoice = "dms" haette also stillschweigend waybar geladen.
  # Spec: docs/superpowers/specs/2026-08-31-dms-migration-design.md
  barModule =
    if barChoice == "noctalia"
    then ./noctalia.nix
    else if barChoice == "dms"
    then ../../meo/dms
    else waybarChoice;
```

Der Pfad `../../meo/dms` zeigt von `modules/upstream/home/` nach `modules/meo/dms/`. Nix lädt aus einem Verzeichnis automatisch `default.nix`.

- [ ] **Schritt 3: Die Paketliste in `modules/upstream/core/packages.nix`**

Der Block `noctaliaPkgs` prüft bereits `barChoice == "noctalia"` und liefert sonst nichts. Er ist damit **schon korrekt** und braucht keine Änderung — prüfe das und lass ihn in Ruhe, falls es zutrifft.

Trifft es nicht zu (also: er lädt Noctalia-Pakete auch bei anderen Werten), ergänze denselben `# MODIFIED 2026-08-31`-Kommentar und stelle sicher, dass nur `"noctalia"` sie zieht.

- [ ] **Schritt 4: Bauen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: **beide unverändert.** `barChoice` steht überall noch auf `"noctalia"`, der neue Zweig wird also nicht betreten. Ein Zweig, den niemand nimmt, darf nichts verändern.

- [ ] **Schritt 5: Den neuen Zweig einmal probehalber betreten**

Nur zur Kontrolle, **ohne** die Datei zu verändern:

```bash
cd /home/meo/nixos-config
nix eval --impure --expr '
  let f = import ./modules/upstream/home/default.nix; in builtins.isFunction f' 2>/dev/null
```

Erwartet: `true`. Der Zweig ist syntaktisch gültig; dass er das richtige Modul wählt, weist Aufgabe 8 nach.

- [ ] **Schritt 6: Commit**

```bash
cd /home/meo/nixos-config
git add modules/upstream/home/default.nix modules/meo/dms/default.nix
git commit -m "dms: barChoice-Weiche dreiwertig machen

Vorher fiel jeder Wert ausser \"noctalia\" auf waybar zurueck — ein
barChoice = \"dms\" haette also stillschweigend waybar geladen. Jetzt
waehlt \"dms\" modules/meo/dms.

Das Modul ist noch ein leeres Geruest; beide Store-Pfade sind
unveraendert, weil barChoice ueberall noch auf noctalia steht."
```

---

### Aufgabe 4: Das DMS-Modul mit Einstellungen

**Dateien:**
- Ändern: `modules/meo/dms/default.nix`
- Erstellt: `modules/meo/dms/settings.nix`
- Ändern: `hosts/meo/variables.nix` (neu: `dmsScreenOff`)

**Schnittstellen:**
- Verbraucht: `inputs.dank-material-shell.homeModules.dank-material-shell` aus Aufgabe 1.
- Erzeugt: `xdg.configFile."DankMaterialShell/settings.json"`, gelesen von DMS zur Laufzeit.

- [ ] **Schritt 1: `dmsScreenOff` in `hosts/meo/variables.nix`**

Direkt unter `idleScreenOff` einfügen:

```nix
  # Bildschirm-Abschaltung fuer DankMaterialShell (fadeToDpmsEnabled).
  # Eigene Variable statt Wiederverwendung von idleScreenOff, weil die beiden
  # Shells verschiedene Schluessel benutzen und getrennt schaltbar bleiben
  # sollen — sonst wuerde ein Wechsel des einen still den anderen mitziehen.
  #
  # AUS auf meo, aus demselben Grund wie idleScreenOff: DPMS-off->on wedged
  # die i915-Pipe des OLED (siehe kernelParams i915.enable_{psr,fbc,dc}=0 in
  # default.nix). Nur Reboot hilft. Diese Sperre ist der Grund, warum die
  # DMS-Konfiguration deklarativ bleiben MUSS statt GUI-Zustand zu werden.
  dmsScreenOff = false;
```

- [ ] **Schritt 2: `modules/meo/dms/settings.nix` anlegen**

```nix
# Erzeugt ~/.config/DankMaterialShell/settings.json aus Nix.
#
# WARUM NICHT UEBER DAS NIX-MODUL: programs.dank-material-shell kennt nur elf
# Optionen (enable, package, systemd.*, sechs Funktionsschalter,
# quickshell.package, plugins) und schreibt KEINE Einstellungsdatei. Die
# eigentliche Schnittstelle ist die Datei, die die Anwendung liest.
#
# WARUM DAS FUNKTIONIERT: DMS prueft zur Laufzeit die Schreibbarkeit von
# settings.json und schaltet sauber in einen Nur-Lese-Modus
# (quickshell/Common/SettingsData.qml, _onWritableCheckComplete). Eine Datei
# aus dem Nix-Store ist schreibgeschuetzt — das ist ein vorgesehener
# Betriebsmodus, kein Fehlerpfad. DMS beobachtet die Datei zusaetzlich und
# laedt sie neu, ein fr wirkt also ohne Neustart des Shells.
#
# Hier stehen nur die Werte, die beim ersten Start stimmen MUESSEN. Alles
# Uebrige bleibt bei DMS' Vorgaben — gleiche Aufteilung wie in
# modules/upstream/home/noctalia.nix.
{
  host,
  pkgs,
  ...
}: let
  vars = import ../../../hosts/${host}/variables.nix;
in {
  xdg.configFile."DankMaterialShell/settings.json".source =
    (pkgs.formats.json {}).generate "dms-settings.json" {
      # Bildschirm-Abschaltung. Auf meo AUS gegen den eDP-OLED-Freeze.
      fadeToDpmsEnabled = vars.dmsScreenOff or false;
      fadeToDpmsGracePeriod = 5;

      # Sperr-Zeiten in Sekunden, wie bisher unter Noctalia (600).
      acLockTimeout = 600;
      batteryLockTimeout = 600;
    };
}
```

- [ ] **Schritt 3: `modules/meo/dms/default.nix` füllen**

```nix
# DankMaterialShell — Einstieg. Wird von modules/upstream/home/default.nix
# importiert, wenn barChoice = "dms" in hosts/<host>/variables.nix steht.
#
# Spec: docs/superpowers/specs/2026-08-31-dms-migration-design.md
{inputs, ...}: {
  imports = [
    inputs.dank-material-shell.homeModules.dank-material-shell
    ./settings.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
  };
}
```

- [ ] **Schritt 4: Bauen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: **beide unverändert.** `barChoice` steht noch auf `"noctalia"`, das Modul wird nicht importiert.

- [ ] **Schritt 5: Die erzeugte Datei trotzdem prüfen**

Das Modul wird nicht importiert — die Datei lässt sich aber direkt auswerten:

```bash
cd /home/meo/nixos-config
nix eval --raw --impure --expr '
  let
    pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux;
    m = import ./modules/meo/dms/settings.nix { host = "meo"; inherit pkgs; };
  in m.xdg.configFile."DankMaterialShell/settings.json".source
' | xargs cat
```

Erwartet: gültiges JSON mit **`"fadeToDpmsEnabled": false`**. Das ist die sicherheitsrelevante Zeile; steht dort `true`, ist die Aufgabe nicht erfüllt.

- [ ] **Schritt 6: Commit**

```bash
cd /home/meo/nixos-config
git add modules/meo/dms/default.nix modules/meo/dms/settings.nix hosts/meo/variables.nix
git commit -m "dms: Modul mit deklarativer settings.json

Die Konfiguration laeuft nicht ueber das Nix-Modul (elf Optionen, keine
Einstellungsdatei), sondern ueber die Datei, die DMS liest. DMS
unterstuetzt schreibgeschuetzte Konfiguration ausdruecklich.

fadeToDpmsEnabled kommt aus variables.nix und ist auf meo false — die
eDP-OLED-Freeze-Sperre bleibt damit deklarativ statt GUI-Zustand."
```

---

### Aufgabe 5: niri-Integration

DMS' eigenes niri-Modul einbinden, aber so, dass die gewachsene niri-Config gewinnt.

**Dateien:**
- Erstellt: `modules/meo/dms/niri.nix`
- Ändern: `modules/meo/dms/default.nix` (Import ergänzen)

- [ ] **Schritt 1: Den Attributnamen des HM-Moduls bestätigen**

```bash
cd /home/meo/nixos-config
nix eval --json '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile' --apply 'x: builtins.filter (n: builtins.match ".*niri.*" n != null) (builtins.attrNames x)' 2>&1 | tail -1
```

Erwartet: enthält `"niri/config.kdl"`. Das ist der Eintrag, den der Nachbau umbiegt — DMS' eigenes Modul zielt stattdessen auf `niri-config` aus niri-flake und griffe hier ins Leere.

- [ ] **Schritt 2: `modules/meo/dms/niri.nix` anlegen**

```nix
# DMS' niri-Integration.
#
# DMS bringt homeModules.niri mit, das eigene KDL-Dateien erzeugt und per
# include einbindet. Sein Einbindungs-Trick greift hier aber NICHT: er biegt
# xdg.configFile.niri-config um — ein Attributname aus niri-flake. Dieses Repo
# benutzt das nixpkgs-HM-Modul, das seinen Eintrag "niri/config.kdl" nennt.
# Deshalb wird der Mechanismus hier von Hand nachgebaut.
#
# REIHENFOLGE IST DER GANZE PUNKT: niri-Includes sind positional, spaetere
# ueberschreiben fruehere, und Fensterregeln werden an der include-Zeile
# eingefuegt. DMS' Dateien stehen deshalb ZUERST und die eigene Config
# ZULETZT — damit gewinnen Spaltenbreiten, Zentrierung, Dashboard-Regel und
# die CH-Tastaturbelegung aus modules/meo/niri/.
#
# enableKeybinds bleibt AUS: DMS' Vorschlag belegt Mod+Space, Mod+Comma,
# Mod+V, Mod+X und Mod+M — hier sind das "zwischen Floating und Tiling
# wechseln" und "Fenster in Spalte aufnehmen". Die Binds setzt Aufgabe 6
# von Hand.
{
  inputs,
  lib,
  ...
}: {
  imports = [inputs.dank-material-shell.homeModules.niri];

  programs.dank-material-shell.niri = {
    enableKeybinds = false;
    enableSpawn = false;
    includes = {
      enable = true;
      override = false;
      originalFileName = "hm";
      filesToInclude = ["colors" "cursor" "wpblur"];
    };
  };

  # Nachbau des Einbindungs-Tricks fuer das nixpkgs-HM-Modul.
  # 1. Die vom HM-Modul erzeugte Config nach niri/hm.kdl umleiten.
  # 2. Eine eigene niri/config.kdl schreiben, die erst DMS' Dateien und dann
  #    hm.kdl einbindet.
  #
  # optional=true gibt es seit niri 26.04 (hier im Einsatz): ein fehlendes
  # Teilstueck ist damit eine Warnung im Log statt eines Config-Fehlers, der
  # die Session lahmlegen wuerde.
  xdg.configFile."niri/config.kdl".target = lib.mkForce "niri/hm.kdl";

  xdg.configFile."niri/config-dms" = {
    target = "niri/config.kdl";
    text = ''
      include optional=true "dms/colors.kdl"
      include optional=true "dms/cursor.kdl"
      include optional=true "dms/wpblur.kdl"
      include optional=true "hm.kdl"
    '';
  };
}
```

- [ ] **Schritt 3: Import ergänzen**

In `modules/meo/dms/default.nix` die `imports`-Liste um `./niri.nix` erweitern.

- [ ] **Schritt 4: Bauen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: **beide unverändert** (Gate noch auf noctalia).

- [ ] **Schritt 5: Commit**

```bash
cd /home/meo/nixos-config
git add modules/meo/dms/niri.nix modules/meo/dms/default.nix
git commit -m "dms: niri-Integration mit eigener Config zuletzt

includes.override = false stellt DMS' Dateien VOR die eigene Config.
Da niri-Includes positional sind und spaetere gewinnen, behalten
Spaltenbreiten, Zentrierung, Dashboard-Regel und CH-Binds den Vorrang.

Der Einbindungs-Trick des DMS-Moduls zielt auf niri-flake
(xdg.configFile.niri-config) und greift beim nixpkgs-Modul nicht —
hier von Hand nachgebaut gegen \"niri/config.kdl\"."
```

---

### Aufgabe 6: Die neun Binds

**Dateien:**
- Ändern: `modules/meo/niri/binds-apps.nix`

- [ ] **Schritt 1: Die IPC-Namen gegen das Paket abfragen**

```bash
dms=$(nix build --no-link --print-out-paths 'github:AvengeMedia/DankMaterialShell#dms-shell')
"$dms"/bin/dms ipc 2>&1 | head -40
```

Gesucht sind die tatsächlichen Ziele für Launcher, Zwischenablage, Notifications, Control Center, Power-Menü, Einstellungen und **Wallpaper** (offener Punkt 3 des Specs). Die Ausgabe in den Bericht aufnehmen.

- [ ] **Schritt 2: Die Binds umstellen**

`modules/meo/niri/binds-apps.nix` liest bereits `vars` (für `browser` und `terminal`). Ergänze dort `barChoice` und mache die neun Noctalia-Zeilen davon abhängig. Muster:

```nix
  inherit (vars) browser terminal barChoice;

  # Shell-Panels. Die Tasten bleiben gleich, nur der Adressat wechselt mit
  # barChoice — so muss beim Umschalten zwischen den Shells keine
  # Tastenbelegung im Kopf umgelernt werden.
  shellBinds =
    if barChoice == "dms"
    then {
      "Mod+D".spawn = ["dms" "ipc" "call" "spotlight" "toggle"];
      "Mod+Shift+Return".spawn = ["dms" "ipc" "call" "spotlight" "toggle"];
      "Mod+M".spawn = ["dms" "ipc" "call" "notifications" "toggle"];
      "Mod+V".spawn = ["dms" "ipc" "call" "clipboard" "toggle"];
      "Mod+C".spawn = ["dms" "ipc" "call" "control-center" "toggle"];
      "Mod+X".spawn = ["dms" "ipc" "call" "powermenu" "toggle"];
      "Mod+Alt+P".spawn = ["dms" "ipc" "call" "settings" "toggle"];
      "Mod+Shift+Comma".spawn = ["dms" "ipc" "call" "settings" "toggle"];
      "Mod+Shift+W".spawn = ["dms" "ipc" "call" "wallpaper" "toggle"];
    }
    else {
      "Mod+D".spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
      "Mod+Shift+Return".spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
      "Mod+M".spawn = ["noctalia" "msg" "panel-toggle" "control-center" "notifications"];
      "Mod+V".spawn = ["noctalia" "msg" "panel-toggle" "clipboard"];
      "Mod+C".spawn = ["noctalia" "msg" "panel-toggle" "control-center"];
      "Mod+X".spawn = ["noctalia" "msg" "panel-toggle" "session"];
      "Mod+Alt+P".spawn = ["noctalia" "msg" "settings-toggle"];
      "Mod+Shift+Comma".spawn = ["noctalia" "msg" "settings-toggle"];
      "Mod+Shift+W".spawn = ["noctalia" "msg" "panel-toggle" "wallpaper"];
    };
```

Die neun Einzelzeilen aus dem bisherigen `binds`-Attrset entfernen und stattdessen `shellBinds` einmischen (`binds = shellBinds // { … }` oder über `//` am Ende).

**Weicht ein IPC-Name aus Schritt 1 ab, gilt der gemessene Name**, nicht der hier notierte. `Mod+Shift+W` ist der wahrscheinlichste Abweichler.

**`Mod+Alt+L` bleibt unverändert** — es ruft `loginctl lock-session`, ist also shell-neutral.

- [ ] **Schritt 3: Bauen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: **beide unverändert.** `barChoice` steht auf `"noctalia"`, also greift der `else`-Zweig mit exakt den bisherigen Zeilen. Bewegt sich `meo`, wurden die Noctalia-Binds beim Umbau verändert — dann Zeile für Zeile vergleichen.

- [ ] **Schritt 4: Commit**

```bash
cd /home/meo/nixos-config
git add modules/meo/niri/binds-apps.nix
git commit -m "dms: die neun Shell-Binds vom Gate abhaengig machen

Gleiche Tasten, wechselnder Adressat. Der noctalia-Zweig ist mit den
bisherigen Zeilen identisch — nachgewiesen durch unveraenderte
Store-Pfade bei barChoice = noctalia."
```

---

### Aufgabe 7: Stylix-Theming

**Dateien:**
- Erstellt: `modules/meo/dms/theme.nix`
- Ändern: `modules/meo/dms/default.nix` (Import ergänzen)

- [ ] **Schritt 1: Die Theme-Schlüssel bestätigen**

```bash
cd /tmp/claude-1000/-home-meo/90fa53bf-bf51-4a6d-8b74-fdd6a02a882a/scratchpad
grep -nE "currentThemeName|currentThemeCategory|customThemeFile" sd.qml | head
```

`customThemeFile` nimmt einen Pfad. Das erwartete Format zeigt die Stelle, die die Datei einliest:

```bash
cd /tmp/claude-1000/-home-meo/90fa53bf-bf51-4a6d-8b74-fdd6a02a882a/scratchpad
grep -n -A25 "customThemeFile" sd.qml | grep -iE "JSON.parse|\\.parse|primary|surface|error|\\[\"|readFile" | head -20
curl -sSL --max-time 25 "https://api.github.com/repos/AvengeMedia/DankMaterialShell/contents/quickshell/Common/settings" 2>/dev/null | grep -oE '"name": "[^"]+"'
```

Gesucht sind die **Schlüsselnamen**, die DMS aus der Themendatei liest. Sie ersetzen die im nächsten Schritt notierten, falls sie abweichen.

- [ ] **Schritt 2: `modules/meo/dms/theme.nix` anlegen**

Die Stylix-Palette liegt unter `config.lib.stylix.colors`. Die Datei erzeugt daraus eine DMS-Themendatei im Store und verweist per `customThemeFile` darauf:

```nix
# Stylix-Farben nach DankMaterialShell durchreichen.
#
# Noctalia bekam die Farben ueber theme.mode/source/builtin (mit mkForce
# gegen Konflikte mit Stylix' eigener noctalia-Integration). DMS kennt
# stattdessen currentThemeName/currentThemeCategory und customThemeFile.
#
# Der Weg fuehrt ueber customThemeFile: eine aus der Stylix-Palette erzeugte
# Datei im Store, auf die settings.json zeigt.
{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors;

  themeFile = (pkgs.formats.json {}).generate "dms-stylix-theme.json" {
    name = "stylix";
    primary = "#${c.base0D}";
    secondary = "#${c.base0E}";
    surface = "#${c.base00}";
    surfaceText = "#${c.base05}";
    error = "#${c.base08}";
  };
in {
  xdg.configFile."DankMaterialShell/themes/stylix.json".source = themeFile;
}
```

**Die Schlüsselnamen (`primary`, `secondary`, …) sind aus Schritt 1 zu bestätigen** und gegebenenfalls zu ersetzen. Stimmen sie nicht, ignoriert DMS die Datei stillschweigend — deshalb Schritt 4.

- [ ] **Schritt 3: `settings.nix` auf das Thema zeigen lassen**

In `modules/meo/dms/settings.nix` ergänzen:

```nix
      currentThemeName = "stylix";
      currentThemeCategory = "custom";
      customThemeFile = "${config.xdg.configHome}/DankMaterialShell/themes/stylix.json";
```

Dafür muss `settings.nix` `config` als Argument annehmen.

- [ ] **Schritt 4: Bauen und die erzeugten Dateien ansehen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: beide unverändert.

- [ ] **Schritt 5: Commit**

```bash
cd /home/meo/nixos-config
git add modules/meo/dms/theme.nix modules/meo/dms/settings.nix modules/meo/dms/default.nix
git commit -m "dms: Stylix-Farben ueber customThemeFile anbinden"
```

---

### Aufgabe 8: Umschalten

Erst hier bewegt sich `meo`. Alles davor war Vorbereitung hinter einem nicht betretenen Zweig.

**Dateien:**
- Ändern: `hosts/meo/variables.nix` (`barChoice`)
- Löschen: `modules/meo/niri/hyprland-compat.nix`
- Ändern: `modules/meo/niri/default.nix` (Import austragen)

- [ ] **Schritt 1: `hyprland-compat.nix` entfernen**

Die Datei bewacht ausschliesslich `hyprland-monitor-hotplug`, und dieser Dienst stammt aus `noctalia.nix`. Wird Noctalia nicht mehr importiert, existiert er nicht mehr — der Wächter bewacht dann nichts.

```bash
cd /home/meo/nixos-config
git rm modules/meo/niri/hyprland-compat.nix
```

Dann den Eintrag `./hyprland-compat.nix` aus der `imports`-Liste in `modules/meo/niri/default.nix` streichen und dort einen Satz ergänzen, warum:

```nix
    # hyprland-compat.nix ENTFERNT 2026-08-31 (Wechsel auf DMS): der Waechter
    # bewachte hyprland-monitor-hotplug, das aus modules/upstream/home/
    # noctalia.nix stammte. Ohne Noctalia gibt es den Dienst nicht mehr.
    # Nebenwirkung beim Rueckweg auf barChoice = "noctalia": der Dienst kaeme
    # ungewaechtert wieder und wuerde unter niri als failed parken —
    # kosmetisch, kein Funktionsverlust.
```

- [ ] **Schritt 2: Umschalten**

In `hosts/meo/variables.nix`:

```nix
  barChoice = "dms";
```

- [ ] **Schritt 3: Bauen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet:
- `meo` → **neuer** Pfad. Hier ist die Änderung der Erfolg.
- `meo-work` → **unverändert** `ngvh42fb3nqmb7wazpdrvf9l0k028n2h-…`. Bewegt er sich, wurde etwas Gemeinsames angefasst.

Ein Build-Fehler hier bedeutet meist, dass `niri validate` in der `checkPhase` die zusammengesetzte KDL abgelehnt hat.

- [ ] **Schritt 4: Die erzeugte niri-Config prüfen**

```bash
cd /home/meo/nixos-config
cat "$(nix eval --raw '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')"
```

Erwartet: **nur** die vier `include`-Zeilen, mit `hm.kdl` als **letzter**. Steht `hm.kdl` weiter oben, gewinnt DMS statt der eigenen Config — das wäre falsch herum.

- [ ] **Schritt 5: Die erzeugte settings.json prüfen**

```bash
cd /home/meo/nixos-config
cat "$(nix eval --raw '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile."DankMaterialShell/settings.json".source')"
```

Erwartet: gültiges JSON mit `"fadeToDpmsEnabled": false`.

- [ ] **Schritt 6: Prüfen, dass Noctalia wirklich draussen ist**

```bash
cd /home/meo/nixos-config
nix eval --json '.#nixosConfigurations.meo.config.home-manager.users.meo.xdg.configFile' --apply 'x: builtins.filter (n: builtins.match ".*[Nn]octalia.*" n != null) (builtins.attrNames x)' 2>&1 | tail -1
```

Erwartet: `[]`. Kommt hier noch etwas, wird Noctalia trotz Gate eingebunden.

- [ ] **Schritt 7: Commit**

```bash
cd /home/meo/nixos-config
git add -A hosts/meo/variables.nix modules/meo/niri/
git commit -m "dms: auf meo umschalten

barChoice = dms. Noctalia bleibt vollstaendig konfiguriert im Repo und
ist mit einem Wort zurueckschaltbar.

hyprland-compat.nix entfernt: sein Waechter bewachte einen Dienst aus
noctalia.nix, den es ohne Noctalia nicht mehr gibt."
```

---

### Aufgabe 9: Abnahme am Gerät

Keine Codeänderung. Die Schritte 2 bis 8 führt der Nutzer aus.

- [ ] **Schritt 1: Zusammenfassung an den Nutzer**

Mitteilen: was gebaut wurde, dass `fr` und ein erneutes Anmelden nötig sind, und dass der Rückweg `barChoice = "noctalia"` plus `fr` ist.

- [ ] **Schritt 2: `fr`, dann abmelden und neu anmelden**

- [ ] **Schritt 3: Leiste da?**

- [ ] **Schritt 4: Die neun Tasten durchgehen**

`Mod+D`, `Mod+V`, `Mod+M`, `Mod+C`, `Mod+X`, `Mod+Shift+W`, `Mod+Alt+P`. Jede sollte das entsprechende DMS-Panel öffnen. Reagiert eine nicht, stimmt ihr IPC-Name nicht — `dms ipc` zeigt die gültigen.

- [ ] **Schritt 5: Der wichtigste Punkt — Bildschirm bleibt an**

Zehn Minuten nichts tun. Erwartet: die Sitzung sperrt nach 600 s, **der Bildschirm schaltet aber NICHT ab.** Geht er aus und der Rechner hängt beim Aufwachen, ist `fadeToDpmsEnabled` nicht angekommen — dann sofort zurückschalten und melden.

- [ ] **Schritt 6: Sperrbildschirm**

`Mod+Alt+L` sperrt und suspendiert. Nach dem Aufwachen muss ein Sperrbildschirm da sein, auf dem sich das Passwort eingeben lässt.

- [ ] **Schritt 7: Farben**

Passt DMS zum übrigen System, oder steht es in Fremdfarben da? Letzteres heisst, die Schlüsselnamen in `theme.nix` stimmen nicht — kein Beinbruch, aber ein Nacharbeitspunkt.

- [ ] **Schritt 8: Dashboard-Spalte**

Erscheint sie beim ersten Fenster auf einem Workspace weiterhin links? Kollidiert DMS' Dock mit ihr?

---

---

### Nachgelagert: Plugins (eigener Commit, nach der Abnahme)

Der Spec lässt in 5.7 offen, **welche** Plugins — das entscheidet der Nutzer, wenn DMS läuft und er das Register durchsehen kann. Deshalb keine Aufgabe im Ablauf oben, aber die Form steht hier fest, damit sie nicht neu erfunden wird.

Reproduzierbare Plugins sind eines der beiden Motive für diesen Wechsel gewesen (das andere ist die niri-Integration). Dieser Schritt ist also nicht optional-im-Sinne-von-überflüssig, sondern nur zeitlich nachgelagert.

- [ ] **Schritt 1: Register durchsehen**

```bash
dms plugins search
```

- [ ] **Schritt 2: Ausgewählte Plugins deklarativ eintragen**

In `modules/meo/dms/default.nix`, im Block `programs.dank-material-shell`. Die Option nimmt `attrsOf { enable; src; settings; }`, wobei `src` ein Nix-Paket ist — also ein gepinnter Commit mit Hash, kein Laufzeit-Fetch:

```nix
    plugins = {
      BeispielPlugin = {
        enable = true;
        src = pkgs.fetchFromGitHub {
          owner = "…";
          repo = "…";
          rev = "v1.0.0";
          hash = "sha256-…";
        };
        settings = {};
      };
    };
```

Den Hash liefert ein erster Build mit `hash = lib.fakeHash;` — die Fehlermeldung nennt den richtigen.

Das ist der Unterschied zu Noctalia, der den Wechsel mitbegründet hat: dort zieht der Shell seine Plugins **zur Laufzeit per git** (am 2026-08-31 im Journal beobachtet), der Stand hängt also davon ab, wann zuletzt gefetcht wurde. Hier steht er im Flake.

- [ ] **Schritt 3: Bauen, `meo-work` muss unverändert bleiben, dann Commit**

---

## Bekannte Nebenwirkungen

- **`bt-audio-monitor` verschwindet.** Bewusst fallengelassen (er lief, funktionierte laut Nutzer aber nie zuverlässig). Die Derivation `modules/meo/scripts/bt-audio-monitor.nix` bleibt ungenutzt liegen; ihr Entfernen ist ein eigener Aufräumschritt.
- **`hyprland-monitor-hotplug` verschwindet.** Er stand unter niri ohnehin still (`inactive`, gehalten vom Wächter). Kein Funktionsverlust.
- **Beim Rückweg auf Noctalia** kommt dieser Dienst ungewächtert wieder und parkt unter niri als `failed`. Kosmetisch.
- **Die Hyprland-Rückfallsession** bekommt bei `barChoice = "dms"` über `modules/upstream/home/hyprland/binds.nix` die Rofi-Bindungen statt der Noctalia-Bindungen (der `!= "noctalia"`-Zweig). Betrifft nur diese selten benutzte Session.
- **`niri-ribbon`**, das Noctalia-Widget für Fenster ausserhalb des Bildes, ist unter DMS nicht verfügbar. Es war nie installiert — nur als Möglichkeit besprochen.
