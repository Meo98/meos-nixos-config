# meo-work auf niri — Implementierungsplan

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte verwenden Checkbox-Syntax (`- [ ]`) zur Nachverfolgung.

**Ziel:** Host `meo-work` startet in eine niri-Session statt in Hyprland, unter Wiederverwendung des bestehenden niri-Moduls und ohne jede Verhaltensänderung auf Host `meo`.

**Architektur:** Die einzige hostspezifische Datei des niri-Moduls (`outputs.nix`) wird von fest verdrahteten Werten auf `hosts/<host>/variables.nix` umgestellt — dem Muster folgend, das `input.nix` und `binds-apps.nix` bereits verwenden. Danach importiert `meo-work` dasselbe Modul und bringt nur seine eigenen Monitorwerte mit. Hyprland bleibt installiert und als Session wählbar.

**Tech-Stack:** Nix / NixOS-Flakes, home-manager, niri 26.04, KDL-Generierung über `lib.hm.generators.toKDL`.

**Spec:** `docs/superpowers/specs/2026-08-31-meo-work-niri-migration-design.md`

## Globale Randbedingungen

- **Niemals** `fr`, `nh os switch`, `nixos-rebuild`, `systemctl` oder `loginctl` ausführen. Rebuilds macht ausschliesslich der Nutzer.
- **Niemals** ohne Rückfrage pushen oder mergen. Commits sind erlaubt.
- **Niemals** `modules/upstream/`, `modules/meo/default.nix` oder `modules/meo/scripts.nix` anfassen.
- `nh os build` ist auf `/home/meo/nixos-config` festgenagelt. Jede Prüfung läuft deshalb über `nix build --no-link --print-out-paths '.#nixosConfigurations.<host>.config.system.build.toplevel'`.
- **Baseline-Store-Pfade vor Beginn** (gemessen 2026-08-31):
  - `meo` → `/nix/store/853ksaq87f53cn3i189rm7aj0mbcm61d-nixos-system-meo-26.11.20260822.2c423e0`
  - `meo-work` → `/nix/store/rgcah1jwg4l50s89mppxwk12yp4djynx-nixos-system-meo-work-26.11.20260822.2c423e0`
- Jede Aufgabe endet mit einem Commit. Commit-Nachrichten auf Deutsch, im Stil des bestehenden Verlaufs.
- Kommentare im Code auf Deutsch, ohne Umlaute (bestehende Konvention in `modules/meo/`).

---

### Aufgabe 1: `outputs.nix` variablengetrieben machen

Reine Refaktorierung. Die Werte wandern aus dem Modul in `hosts/meo/variables.nix`;
das erzeugte System muss **bitgleich** bleiben. Das ist der wichtigste Test des
gesamten Teilprojekts: wandert der Store-Pfad, wurde beim Verschieben etwas
verändert, ohne dass es jemand bemerkt hat.

**Dateien:**
- Ändern: `hosts/meo/variables.nix` (neues Attribut `niriOutputs`)
- Ändern: `modules/meo/niri/outputs.nix` (vollständig ersetzt)

**Schnittstellen:**
- Erzeugt: `vars.niriOutputs` — Liste von Attrsets mit den Schlüsseln
  `name` (String, Anschluss- oder EDID-Name), `scale` (Float),
  `x` (Int), `y` (Int) und optional `mode` (String).
  Aufgabe 2 befüllt dieselbe Struktur für `meo-work`.

- [ ] **Schritt 1: Baseline festhalten**

```bash
cd /home/meo/nixos-config
nix build --no-link --print-out-paths '.#nixosConfigurations.meo.config.system.build.toplevel'
```

Erwartet: `/nix/store/853ksaq87f53cn3i189rm7aj0mbcm61d-nixos-system-meo-26.11.20260822.2c423e0`

Weicht der Pfad hier schon ab, wurde seit dem 2026-08-31 etwas anderes geändert.
Dann diesen neuen Pfad als Baseline notieren und weiterarbeiten — der Vergleich
in Schritt 5 zählt gegen den Wert von *hier*, nicht gegen den im Plan.

- [ ] **Schritt 2: `niriOutputs` in `hosts/meo/variables.nix` eintragen**

Direkt nach dem Block `extraMonitorSettings` einfügen. Die Werte sind eine
wortgetreue Übernahme aus `modules/meo/niri/outputs.nix`:

```nix
  # niri-Monitore. Ersetzt fuer die niri-Session das, was
  # extraMonitorSettings oben fuer Hyprland tut.
  #
  # niri rechnet in LOGISCHEN Koordinaten: 2560 / 1.6 = 1600, deshalb liegt
  # DP-1 bei x=1600 — dieselbe Zahl wie in der Hyprland-Zeile.
  #
  # `mode` ist optional. Fehlt es, waehlt niri den bevorzugten Modus; das
  # entspricht "preferred" in der Hyprland-Notation.
  niriOutputs = [
    {
      name = "eDP-1";
      mode = "2560x1600@240.000";
      scale = 1.6;
      x = 0;
      y = 0;
    }
    {
      name = "DP-1";
      scale = 1.2;
      x = 1600;
      y = 141;
    }
  ];
```

- [ ] **Schritt 3: `modules/meo/niri/outputs.nix` ersetzen**

Vollständiger neuer Inhalt der Datei:

```nix
# Monitor-Konfiguration.
#
# Die Werte stehen in hosts/<host>/variables.nix unter niriOutputs; diese Datei
# uebersetzt sie nur in die _children/_args-Form, die der KDL-Generator
# erwartet. Gleiche Aufteilung wie input.nix (keyboardLayout) und
# binds-apps.nix (terminal, browser).
#
# MODIFIED 2026-08-31: von fest verdrahteten meo-Werten auf variables.nix
# umgestellt, damit meo-work dasselbe Modul benutzen kann, statt eine zweite
# Kopie zu pflegen, die auseinanderlaeuft.
#
# niri rechnet Positionen in LOGISCHEN Koordinaten. `mode` ist optional: fehlt
# es, waehlt niri den bevorzugten Modus.
#
# Reihenfolge der output-Bloecke ist bedeutungslos, deshalb duerfen sie in einer
# eigenen Datei liegen (anders als window-rule, siehe rules.nix).
{
  host,
  lib,
  ...
}: let
  vars = import ../../../hosts/${host}/variables.nix;
  outputs = vars.niriOutputs or [];

  toOutput = o: {
    output =
      {
        _args = [o.name];
        scale = o.scale;
        position._props = {
          inherit (o) x y;
        };
      }
      // lib.optionalAttrs (o ? mode) {inherit (o) mode;};
  };
in {
  wayland.windowManager.niri.settings._children = map toOutput outputs;
}
```

- [ ] **Schritt 4: Bauen**

```bash
cd /home/meo/nixos-config
nix build --no-link --print-out-paths '.#nixosConfigurations.meo.config.system.build.toplevel'
```

Erwartet: Build läuft durch. Ein Fehler hier bedeutet meist, dass `niri validate`
in der `checkPhase` die erzeugte KDL abgelehnt hat — die Fehlermeldung nennt dann
Zeile und Knoten.

- [ ] **Schritt 5: Store-Pfad gegen die Baseline prüfen**

Der Pfad aus Schritt 4 muss **identisch** mit dem aus Schritt 1 sein.

Bei Abweichung: die erzeugte KDL beider Stände vergleichen, statt zu raten.

Der erzeugte Eintrag hat **`.source`** (einen Store-Pfad), **nicht** `.text` —
verifiziert am 2026-08-31. Die Datei wird deshalb über den Store-Pfad gelesen:

```bash
cd /home/meo/nixos-config
kdl() { cat "$(nix eval --raw ".#nixosConfigurations.$1.config.home-manager.users.meo.xdg.configFile.\"niri/config.kdl\".source")"; }
kdl meo > /tmp/niri-neu.kdl
git stash
kdl meo > /tmp/niri-alt.kdl
git stash pop
diff /tmp/niri-alt.kdl /tmp/niri-neu.kdl
```

Erwartet: `diff` gibt nichts aus.

- [ ] **Schritt 6: Auch meo-work prüfen**

```bash
cd /home/meo/nixos-config
nix build --no-link --print-out-paths '.#nixosConfigurations.meo-work.config.system.build.toplevel'
```

Erwartet: `/nix/store/rgcah1jwg4l50s89mppxwk12yp4djynx-nixos-system-meo-work-26.11.20260822.2c423e0`

meo-work importiert das niri-Modul noch gar nicht, der Pfad darf sich also nicht
bewegen. Tut er es doch, wurde versehentlich etwas Gemeinsames angefasst.

- [ ] **Schritt 7: Commit**

```bash
cd /home/meo/nixos-config
git add hosts/meo/variables.nix modules/meo/niri/outputs.nix
git commit -m "niri: Monitorwerte aus outputs.nix nach variables.nix ziehen

Reine Refaktorierung als Vorbereitung fuer meo-work. outputs.nix war die
einzige hostspezifische Datei des niri-Moduls; sie uebersetzt jetzt nur
noch, statt Werte zu halten. Gleiche Aufteilung wie input.nix.

Nachgewiesen unveraendert: der Store-Pfad von meo ist vor und nach der
Umstellung identisch."
```

---

### Aufgabe 2: Monitorwerte für meo-work eintragen

Die Werte sind nach dieser Aufgabe noch **wirkungslos**, weil meo-work das
niri-Modul erst in Aufgabe 3 importiert. Das ist beabsichtigt: die
Monitor-Übersetzung lässt sich so unabhängig prüfen und zurückweisen, ohne dass
gleichzeitig die Session umschaltet.

**Dateien:**
- Ändern: `hosts/meo-work/variables.nix` (neues Attribut `niriOutputs`)

**Schnittstellen:**
- Verbraucht: das Schema `niriOutputs` aus Aufgabe 1.

- [ ] **Schritt 1: `niriOutputs` in `hosts/meo-work/variables.nix` eintragen**

Direkt nach dem Block `extraMonitorSettings` einfügen:

```nix
  # niri-Monitore. Uebersetzt aus extraMonitorSettings oben; Hyprland und niri
  # rechnen beide in LOGISCHEN Koordinaten, die Positionen gehen daher 1:1 auf.
  # Nur die Groesse wird durch die Skalierung geteilt: 1920/1.2 = 1600.
  #
  #   HP Z24n      1920x1200@60, 0x0,       1     ->  1920x1200 bei (0, 0)
  #   Dell U2422H  1920x1080@60, 1920x0,    1     ->  1920x1080 bei (1920, 0)
  #   LG (Laptop)  1920x1080@60, 2280x1080, 1.2   ->  1600x900  bei (2280, 1080)
  #
  # ANSCHLUSSNAMEN SIND EINE ANNAHME. Hyprland adressiert die externen Monitore
  # per EDID (desc:), niri kann beides. Die tatsaechlichen Namen zeigt
  # `niri msg outputs` in einer laufenden niri-Session. Stimmen sie nicht,
  # bleiben die betroffenen Monitore auf niris Automatik-Layout — das ist
  # unschoen, aber nicht kaputt.
  #
  # Umstellung auf EDID spaeter: name = "Dell Inc. DELL U2422H 9FGXF83".
  # Achtung, niris Schreibweise ist NICHT identisch mit Hyprlands desc: bei
  # fehlender Seriennummer haengt niri " Unknown" an.
  niriOutputs = [
    {
      name = "DP-1";
      mode = "1920x1200@60.000";
      scale = 1.0;
      x = 0;
      y = 0;
    }
    {
      name = "DP-2";
      mode = "1920x1080@60.000";
      scale = 1.0;
      x = 1920;
      y = 0;
    }
    {
      name = "eDP-1";
      mode = "1920x1080@60.000";
      scale = 1.2;
      x = 2280;
      y = 1080;
    }
  ];
```

- [ ] **Schritt 2: Prüfen, dass beide Hosts unverändert bleiben**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: **beide** Pfade unverändert gegenüber Aufgabe 1.

Das ist der eigentliche Test dieser Aufgabe. Ein neues Attribut in
`variables.nix`, das niemand liest, darf das erzeugte System nicht verändern.
Bewegt sich meo-work hier, liest doch schon irgendetwas `niriOutputs`.

- [ ] **Schritt 3: Commit**

```bash
cd /home/meo/nixos-config
git add hosts/meo-work/variables.nix
git commit -m "meo-work: niri-Monitorwerte eintragen (noch wirkungslos)

Uebersetzung der drei Hyprland-Monitore in niris logische Koordinaten.
Wird erst wirksam, wenn meo-work das niri-Modul importiert.

Anschlussnamen sind eine Annahme und muessen auf dem Geraet mit
'niri msg outputs' verifiziert werden."
```

---

### Aufgabe 3: niri-Modul auf meo-work importieren und Session setzen

Ab hier ändert sich meo-work tatsächlich.

**Dateien:**
- Ändern: `hosts/meo-work/default.nix:10` (home-manager-Imports)
- Ändern: `hosts/meo-work/default.nix` (neuer Block nach den Imports)

**Schnittstellen:**
- Verbraucht: `niriOutputs` aus Aufgabe 2.

- [ ] **Schritt 1: home-manager-Import erweitern**

Zeile 10 von `hosts/meo-work/default.nix`:

```nix
  home-manager.users.${username}.imports = [ ../../modules/meo ];
```

wird zu:

```nix
  home-manager.users.${username}.imports = [ ../../modules/meo ../../modules/meo/niri ];
```

- [ ] **Schritt 2: Systemseite ergänzen**

Direkt nach dem `home-manager.users`-Block einfügen:

```nix
  # --- niri (Migration 2026-08-31) ---
  # Spec: docs/superpowers/specs/2026-08-31-meo-work-niri-migration-design.md
  #
  # Der Import oben ist bewusst hostlokal und steht nicht in
  # modules/meo/default.nix — dieselbe Trennung wie auf meo.
  #
  # Bewusst NICHT niri-smart: der Wrapper aus modules/meo/niri-gpu-smart.nix
  # ist der NVIDIA-Umschalter und auf dieser reinen Intel-Maschine gegenstands-
  # los. meo-work bekommt die schlichte niri-session.
  #
  # mkForce nagelt die Session explizit fest und sichert sie gegen das
  # mkDefault "niri" des niri-Moduls ab (Grund laut dessen Quellkommentar:
  # verhindert eine GDM-Login-Schleife bei reinen niri-Setups). Hyprland
  # selbst setzt defaultSession nicht. Hyprland bleibt installiert und im
  # SDDM-Menue waehlbar — das ist der Rueckweg ohne Rebuild.
  programs.niri.enable = true;
  services.displayManager.defaultSession = lib.mkForce "niri";
```

- [ ] **Schritt 3: Bauen und prüfen, dass sich nur meo-work bewegt**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet:
- `meo` → unverändert `853ksaq87f53cn3i189rm7aj0mbcm61d-…`
- `meo-work` → **neuer** Pfad

Läuft der Build durch, hat `niri validate` die erzeugte KDL bereits akzeptiert —
das passiert automatisch in der `checkPhase` des home-manager-Moduls.

- [ ] **Schritt 4: Die erzeugte Config auf die drei Monitore prüfen**

Der Eintrag hat **`.source`** (einen Store-Pfad), **nicht** `.text` — verifiziert
am 2026-08-31.

```bash
cd /home/meo/nixos-config
cat "$(nix eval --raw '.#nixosConfigurations.meo-work.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" | grep -A4 '^output'
```

Erwartet: drei `output`-Blöcke mit den Namen `DP-1`, `DP-2`, `eDP-1` und den
Positionen `0,0`, `1920,0` und `2280,1080`.

- [ ] **Schritt 5: Prüfen, dass das Tastaturlayout mitkommt**

```bash
cd /home/meo/nixos-config
cat "$(nix eval --raw '.#nixosConfigurations.meo-work.config.home-manager.users.meo.xdg.configFile."niri/config.kdl".source')" | grep -A3 'xkb'
```

Erwartet: `layout "ch"` — `input.nix` liest das aus `variables.nix`, meo-work
steht dort auf `ch`.

- [ ] **Schritt 6: Commit**

```bash
cd /home/meo/nixos-config
git add hosts/meo-work/default.nix
git commit -m "meo-work: niri-Session aktivieren

Importiert modules/meo/niri und setzt defaultSession auf niri. Bewusst
die schlichte niri-session statt niri-smart — der Wrapper ist der
NVIDIA-Umschalter und hier gegenstandslos.

Hyprland bleibt installiert und im SDDM-Menue waehlbar."
```

---

### Aufgabe 4: `hyprland-monitor-restore` unter niri stilllegen

Die System-Unit stellt nach dem Aufwachen das Hyprland-Monitorlayout wieder her.
Unter niri ist sie gegenstandslos, weil `outputs.nix` die Ausgänge deklarativ
setzt — sie würde nur scheitern und als `failed` stehen bleiben.

**Dateien:**
- Ändern: `hosts/meo-work/default.nix`, Block `systemd.services.hyprland-monitor-restore`

**Die Stelle über den Inhalt suchen, nicht über eine Zeilennummer.** Aufgabe 3
fügt weiter oben in derselben Datei einen Block ein und verschiebt damit alles
darunter. Der unten zitierte `serviceConfig`-Block ist eindeutig.

- [ ] **Schritt 1: `ExecCondition` ergänzen**

Im Block `systemd.services.hyprland-monitor-restore` wird `serviceConfig` von:

```nix
    serviceConfig = {
      Type = "oneshot";
      User = "meo";
      Environment = "HYPRLAND_INSTANCE_SIGNATURE=%t/hypr";
      ExecStart = "/bin/sh -c 'sleep 2 && HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/ 2>/dev/null | head -1) hyprctl reload'";
    };
```

zu:

```nix
    serviceConfig = {
      Type = "oneshot";
      User = "meo";
      Environment = "HYPRLAND_INSTANCE_SIGNATURE=%t/hypr";

      # MODIFIED 2026-08-31 (niri-Migration): unter niri ueberspringen.
      #
      # Die Unit ist dort gegenstandslos, weil modules/meo/niri/outputs.nix die
      # Ausgaenge deklarativ setzt. Ohne Waechter liefe sie nach jedem Resume
      # ins Leere und parkte als "failed".
      #
      # Sie wird NICHT geloescht: Hyprland bleibt Rueckfall-Session und braucht
      # sie dort unveraendert.
      #
      # Anders als der Waechter in modules/meo/niri/hyprland-compat.nix kann
      # der hier NICHT auf $NIRI_SOCKET pruefen — das ist eine SYSTEM-Unit, und
      # niri importiert die Variable nur in den User-Manager. Stattdessen wird
      # direkt nach dem Socket gesucht. Der Dateiname enthaelt die PID
      # (niri.wayland-1.2351.sock), deshalb ein Glob.
      #
      # systemd ueberspringt eine Unit sauber (inactive, NICHT failed), wenn
      # ExecCondition mit 1..254 endet.
      ExecCondition = "/bin/sh -c '! ls /run/user/1000/niri.wayland-*.sock >/dev/null 2>&1'";

      ExecStart = "/bin/sh -c 'sleep 2 && HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/ 2>/dev/null | head -1) hyprctl reload'";
    };
```

- [ ] **Schritt 2: Bauen**

```bash
cd /home/meo/nixos-config
for h in meo meo-work; do printf '%-10s ' "$h"; nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.system.build.toplevel"; done
```

Erwartet: `meo` unverändert, `meo-work` neuer Pfad.

- [ ] **Schritt 3: Die erzeugte Unit-Datei prüfen**

```bash
cd /home/meo/nixos-config
out=$(nix build --no-link --print-out-paths '.#nixosConfigurations.meo-work.config.system.build.toplevel')
cat "$out/etc/systemd/system/hyprland-monitor-restore.service"
```

Erwartet: eine Zeile `ExecCondition=` mit dem Glob auf `niri.wayland-*.sock`,
und die `ExecStart`-Zeile unverändert daneben.

- [ ] **Schritt 4: Commit**

```bash
cd /home/meo/nixos-config
git add hosts/meo-work/default.nix
git commit -m "meo-work: hyprland-monitor-restore unter niri ueberspringen

Die Unit ist unter niri gegenstandslos (outputs.nix setzt die Ausgaenge
deklarativ) und wuerde nach jedem Resume als failed parken.

ExecCondition prueft den Socket-Pfad statt NIRI_SOCKET: das hier ist
eine System-Unit, und niri importiert die Variable nur in den
User-Manager."
```

---

### Aufgabe 5: Abnahme am Gerät

Diese Aufgabe enthält **keine Codeänderung**. Sie ist die Liste dessen, was nur
auf der Maschine selbst prüfbar ist. Die Schritte 2 bis 7 führt der Nutzer aus.

- [ ] **Schritt 1: Zusammenfassung an den Nutzer**

Mitteilen: was gebaut wurde, dass `fr` nötig ist, dass der Rückweg über das
SDDM-Menü läuft (Hyprland wählen, ein Reboot, kein Rebuild), und dass die
Anschlussnamen der Monitore eine unbestätigte Annahme sind.

- [ ] **Schritt 2: Nutzer führt `fr` aus, dann Neustart**

- [ ] **Schritt 3: Anschlussnamen verifizieren**

```bash
niri msg outputs
```

Stimmen die Namen nicht mit `DP-1` / `DP-2` / `eDP-1` überein, die tatsächlichen
Werte in `hosts/meo-work/variables.nix` eintragen. Bei Monitoren, die beim
Umstecken die Nummer wechseln, stattdessen den EDID-Namen aus der Ausgabe
verwenden — **wortgetreu**, samt doppeltem Leerzeichen und `Unknown`.

- [ ] **Schritt 4: Monitorlayout prüfen**

Drei Bildschirme, LG-Panel unterhalb des rechten Monitors, Fenster wandern beim
Ziehen an den erwarteten Kanten über.

- [ ] **Schritt 5: Eingabe prüfen**

Schweizer Layout in einem Terminal, `kanata`-Umbelegungen aktiv,
Fokus-folgt-Maus über Monitorgrenzen hinweg.

- [ ] **Schritt 6: Shell und Dashboard prüfen**

Noctalia-Leiste ist da; beim Öffnen des ersten Fensters auf einem Workspace
erscheint links die Dashboard-Spalte.

- [ ] **Schritt 7: Resume prüfen**

Suspend und Aufwachen. Danach:

```bash
systemctl status hyprland-monitor-restore
```

Erwartet: `inactive (dead)`, **nicht** `failed` — der Wächter aus Aufgabe 4 hat
gegriffen.

- [ ] **Schritt 8: Den GPU-Engpass neu bewerten**

`hosts/meo-work/host-packages.nix:37` hält fest, dass drei Monitore plus das
Noctalia-Overlay den Compositing-Pfad der iGPU zum Flaschenhals machen. niri und
Hyprland komponieren unterschiedlich, der Befund gilt also nicht automatisch
weiter.

Beobachten, ob Fensterbewegungen und Scrollen auf allen drei Bildschirmen flüssig
bleiben. Falls nicht, ist das ein eigener Befund für Teilprojekt B — dort wird
das Overlay ohnehin ausgetauscht. Kein Blocker für die Abnahme hier.

---

## Bekannte Nebenwirkungen

Kein Blocker, aber vor der Abnahme zu wissen:

- **Ein paar `spawn`-Binds zeigen ins Leere.** `binds-apps.nix` belegt Tasten mit
  `obs`, `gimp`, `discord` und `thunar`; auf meo-work ist `thunarEnable = false`,
  und die anderen sind dort nicht zwingend installiert. Ein Tastendruck macht
  dann schlicht nichts. Kein Build-Fehler, kein Absturz.
- **`bright-smart` bekommt auf meo-work ein meo-Argument.** Der Bind übergibt
  `card0-HDMI-A-1` als Zielausgang. Auf meo-work heisst der Ausgang anders; die
  Helligkeitstasten wirken dann nur auf das interne Panel. Behebbar, sobald
  Schritt 3 der Abnahme die echten Namen geliefert hat.
- **Die Dashboard-Spalte kommt auf meo-work automatisch mit**, weil
  `dashboard.nix` host-neutral ist. `kitty` ist dort vorhanden (geprüft), die
  Spalte funktioniert also. Das ist gewollt.
