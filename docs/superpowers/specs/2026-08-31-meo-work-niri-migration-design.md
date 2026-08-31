# niri-Migration (Host `meo-work`) — Design-Spec

Datum: 2026-08-31
Status: umgesetzt (Commits `5ff1d1c..42c820a`)
Vorgänger: `2026-08-27-niri-migration-design.md` (Host `meo`)

Dies ist **Teilprojekt A** eines dreiteiligen Umbaus. B (Noctalia → DankMaterialShell
auf beiden Hosts) und C (SDDM-Theme → dank-greeter) folgen in eigenen Specs. Die
Reihenfolge ist bewusst: läuft meo-work erst auf niri, muss B nur noch *eine*
Shell-Integration lösen statt zwei.

## 1. Problem & Kontext

`meo` läuft seit dem 2026-08-27 auf niri. `meo-work` läuft weiterhin auf Hyprland.
Der Wunsch ist, beide Hosts auf denselben Compositor zu bringen.

Der Auslöser ist nicht Unzufriedenheit mit Hyprland auf meo-work, sondern das
nachgelagerte Teilprojekt B: eine Shell-Migration gegen zwei verschiedene
Compositors zu bauen heißt, die Hyprland-Hälfte davon anzulegen und wenige Tage
später wieder wegzuwerfen.

**Ausgangslage meo-work:**

| | |
|---|---|
| Hardware | Intel Tiger Lake, iGPU, 16 GB RAM |
| Displays | drei: HP Z24n, Dell U2422H, LG-Laptoppanel |
| Tastatur | `ch` / Konsole `sg`, dazu `kanata` |
| Terminal / Browser | ghostty / vivaldi |
| Shell | Noctalia (bleibt in diesem Teilprojekt unverändert) |
| Session | Hyprland, **ohne** explizites `defaultSession` — greift der Upstream-Default |

## 2. Ziele / Nicht-Ziele

**Ziele**

- meo-work startet standardmäßig in eine niri-Session.
- Das bestehende niri-Modul wird **wiederverwendet**, nicht kopiert.
- Das Verhalten auf `meo` bleibt bitgleich — nachgewiesen über einen
  unveränderten Store-Pfad.
- Hyprland bleibt als Rückfall-Session wählbar.

**Nicht-Ziele**

- Kein Shell-Wechsel. Noctalia bleibt in diesem Schritt auf beiden Hosts.
- Kein `niri-smart`. Der Wrapper ist der NVIDIA-Umschalter und auf einer
  reinen Intel-Maschine gegenstandslos.
- Keine Änderung an Audio-Fixes, zram, Affinity, NFS oder kanata.

## 3. Verifizierte Grundlagen

Alles hier wurde am 2026-08-31 gemessen, nicht aus dem Gedächtnis übernommen.

**Nur eine Datei des niri-Moduls ist hostspezifisch.** Von den elf Dateien in
`modules/meo/niri/` lesen zwei ihre hostabhängigen Werte bereits aus
`hosts/<host>/variables.nix`; die übrigen acht (ohne `default.nix`, das nur
importiert) enthalten gar keine:

| Datei | hostspezifisch? |
|---|---|
| `outputs.nix` | **ja** — eDP-1 / DP-1 fest verdrahtet |
| `input.nix` | nein — `keyboardLayout` aus `variables.nix` |
| `binds-apps.nix` | **ja** — `terminal`/`browser` kommen aus `variables.nix`, aber die `bright-smart`-Binds (Zeilen ~123/127) verdrahten `card0-HDMI-A-1` als Zielausgang fest; siehe „Bekannte Nebenwirkungen" im Plan |
| `env.nix`, `layout.nix`, `binds-nav.nix`, `rules.nix`, `startup.nix`, `dashboard.nix`, `hyprland-compat.nix` | nein |

**niri benennt Ausgänge auf zwei Arten.** Gemessen auf `meo`:

```
Output "Samsung Display Corp. ATNA60DL01-0  Unknown" (eDP-1)
```

Also entweder Anschlussname (`eDP-1`) oder EDID-Tripel `"Hersteller Modell Seriennummer"`.
Die EDID-Schreibweise ist **nicht** identisch mit Hyprlands `desc:` — niri hängt bei
fehlender Seriennummer `Unknown` an und trennt hier mit zwei Leerzeichen.

**Positionen sind in beiden Compositors logisch.** Die Umrechnung ist deshalb
verlustfrei; nur die Größe wird durch die Skalierung geteilt.

## 4. Getroffene Entscheidungen

| # | Entscheidung | Begründung |
|---|---|---|
| 1 | `outputs.nix` wird variablengetrieben statt kopiert | folgt dem Muster von `input.nix`; verhindert eine zweite, driftende Kopie des Moduls |
| 2 | Anschlussnamen (`DP-1`) statt EDID als Startwert | funktionieren sicher ohne Zugriff auf meo-work; EDID ist eine spätere Härtung |
| 3 | Schlichte `niri-session`, kein `niri-smart` | kein NVIDIA vorhanden |
| 4 | `hyprland-monitor-restore` bekommt einen Wächter statt gelöscht zu werden | Hyprland bleibt Rückfall-Session und braucht die Unit dort weiterhin |
| 5 | Hyprland bleibt installiert | Rückweg ohne Rebuild, nur Reboot |

## 5. Architektur

### 5.1 `outputs.nix` wird zur Übersetzungsschicht

Heute steht die Monitor-Geometrie als Literal im Modul. Künftig steht sie in
`hosts/<host>/variables.nix` unter `niriOutputs`, und `outputs.nix` übersetzt sie
in die `_children`/`_args`-Form, die der KDL-Generator erwartet.

Die Form in `variables.nix` bleibt bewusst nah an niris eigenem Vokabular
(`mode`, `scale`, `x`, `y`) statt eine eigene Abstraktion zu erfinden.

```nix
# hosts/meo/variables.nix — unveränderte Werte, nur verschoben
niriOutputs = [
  { name = "eDP-1"; mode = "2560x1600@240.000"; scale = 1.6; x = 0;    y = 0;   }
  { name = "DP-1";                              scale = 1.2; x = 1600; y = 141; }
];
```

`mode` ist optional; fehlt es, wählt niri den bevorzugten Modus — das entspricht
`preferred` in der Hyprland-Notation.

### 5.2 Monitor-Übersetzung meo-work

| Monitor | Hyprland heute | niri (logisch) |
|---|---|---|
| HP Z24n | `1920x1200@60, 0x0, 1` | 1920×1200 bei (0, 0) |
| Dell U2422H | `1920x1080@60, 1920x0, 1` | 1920×1080 bei (1920, 0) |
| LG Laptop | `1920x1080@60, 2280x1080, 1.2` | 1600×900 bei (2280, 1080) |

```nix
# hosts/meo-work/variables.nix
niriOutputs = [
  { name = "DP-1";  mode = "1920x1200@60.000"; scale = 1.0; x = 0;    y = 0;    }
  { name = "DP-2";  mode = "1920x1080@60.000"; scale = 1.0; x = 1920; y = 0;    }
  { name = "eDP-1"; mode = "1920x1080@60.000"; scale = 1.2; x = 2280; y = 1080; }
];
```

Die Anschlussnamen der beiden externen Monitore sind **eine Annahme** und müssen
auf meo-work verifiziert werden — siehe Abschnitt 7.

### 5.3 Systemseite

`hosts/meo-work/default.nix` bekommt, analog zu `hosts/meo/default.nix`:

```nix
home-manager.users.${username}.imports = [ ../../modules/meo ../../modules/meo/niri ];

programs.niri.enable = true;
services.displayManager.defaultSession = lib.mkForce "niri";
```

`mkForce` nagelt die Session explizit fest und sichert sie gegen das
`mkDefault "niri"` des niri-Moduls ab (Grund laut dessen Quellkommentar:
verhindert eine GDM-Login-Schleife bei reinen niri-Setups). Hyprland selbst
setzt `defaultSession` nicht.

Der Import bleibt **hostlokal** und wandert nicht nach `modules/meo/default.nix` —
dieselbe Trennung, die schon auf meo dafür sorgt, dass ein Host den niri-Code im
Repo hat, ohne ihn in seiner Session zu bekommen.

### 5.4 `hyprland-monitor-restore` unter niri stilllegen

Die System-Unit in `hosts/meo-work/default.nix` stellt nach dem Aufwachen das
Hyprland-Monitorlayout wieder her. Unter niri ist sie gegenstandslos, weil
`outputs.nix` die Ausgänge deklarativ setzt.

Sie wird **nicht gelöscht**, sondern bekommt einen `ExecCondition`-Wächter.

**Umgesetzt wurde die Socket-Glob-Variante, nicht `NIRI_SOCKET`.** Der
ursprünglich hier skizzierte Ansatz (`[ -z "''${NIRI_SOCKET:-}" ]`, wie
`hyprland-compat.nix` es für `hyprland-monitor-hotplug` verwendet) geht nicht:
das hier ist eine **System**-Unit, keine User-Unit, und `NIRI_SOCKET` wird von
niri nur in den *User*-Manager importiert — im System-Kontext ist die Variable
nicht sichtbar (Abschnitt 7, Punkt 2 war offen, jetzt geklärt). Stattdessen
prüft die Unit direkt auf den Socket selbst:

```nix
ExecCondition = "/bin/sh -c '! ls /run/user/1000/niri.wayland-*.sock >/dev/null 2>&1'";
```

Der Socketname ist `niri.<wayland-display>.<pid>.sock` (niri-Quelle,
`src/ipc/server.rs`) — er enthält die PID des laufenden niri-Prozesses, ein
fest notierter Name kann also nie treffen. Daher der Glob statt eines
Literalpfads.

systemd überspringt eine Unit sauber (`inactive`, **nicht** `failed`), wenn
`ExecCondition` mit 1..254 endet. Unter der Hyprland-Rückfallsession läuft sie
unverändert weiter.

## 6. Was unverändert bleibt

- **kanata** arbeitet auf evdev-Ebene, unterhalb des Compositors.
- **Noctalia** bleibt Shell auf beiden Hosts (Teilprojekt B).
- **`niri-gpu-smart.nix`** bleibt meo-exklusiv.
- **Die Dashboard-Spalte** kommt auf meo-work automatisch mit, weil
  `dashboard.nix` host-neutral ist. Das ist gewollt.

## 7. Offene Punkte

| # | Punkt | Klärung |
|---|---|---|
| 1 | Anschlussnamen der drei Monitore auf meo-work | `niri msg outputs` in einer niri-Session, oder vorab `ls /sys/class/drm/` — Abnahme am Gerät steht noch aus |
| 2 | Ist `NIRI_SOCKET` in einer System-Unit sichtbar? | **Entschieden: nein.** `NIRI_SOCKET` wird nur in den User-Manager importiert, im System-Kontext (`hyprland-monitor-restore` ist eine System-Unit) nicht sichtbar. Umgesetzt: `ExecCondition` grept direkt nach dem Socket-Glob `/run/user/1000/niri.wayland-*.sock`, siehe Abschnitt 5.4. |
| 3 | Drei Monitore + Noctalia waren laut Kommentar in `host-packages.nix` ein GPU-Engpass | unter niri neu bewerten; kein Blocker |
| 4 | **Beim Abschluss-Review entdeckt:** hypridle haengt an `hyprland-session.target` und startet unter niri nicht — damit fehlt sein `before_sleep_cmd` (`loginctl lock-session`), der die Session vor dem Suspend sperrt. Ohne Hook wuerde `services.logind.lidSwitch = "suspend"` (Default, `hosts/meo-work/` setzt nichts Eigenes) die Maschine beim Zuklappen **ungesperrt** suspendieren. Noctalias Idle-Lock ist ein 600-s-Timer, kein Suspend-Hook. | **Geloest:** geteiltes NixOS-Modul `modules/meo/lock-before-sleep.nix` (System-Unit `lock-before-sleep`, `before`/`wantedBy = sleep.target`, ruft `loginctl lock-sessions`). Importiert aus `hosts/meo/default.nix` UND `hosts/meo-work/default.nix`, nicht kopiert — verhindert das erneute Auseinanderlaufen. Store-Pfad von `meo` bleibt dabei nachweislich unveraendert (Unit war dort vorher bereits inline vorhanden, nur ausgelagert). |

Punkt 1 blockiert die Umsetzung nicht — er hat einen sicheren Startwert
(Anschlussnamen). Punkt 2 und 4 sind entschieden bzw. gelöst.

## 8. Verifikation

1. `nix build` für **beide** Hosts, vor jedem Commit.
2. **Store-Pfad-Vergleich für `meo` vor und nach der `outputs.nix`-Umstellung.**
   Identischer Pfad = die Umstellung auf `variables.nix` hat meo nicht verändert.
   Das ist der wichtigste Test des ganzen Teilprojekts.
3. `niri validate` läuft automatisch in der `checkPhase` des HM-Moduls.
4. Auf meo-work nach dem Reboot: Monitorpositionen, `kanata`, Noctalia-Leiste,
   Dashboard-Spalte.

## 9. Rückweg

Im SDDM-Menü Hyprland wählen — ein Reboot, kein Rebuild. Fällt die Entscheidung
dauerhaft gegen niri, genügt es, den Import und `defaultSession` aus
`hosts/meo-work/default.nix` zu entfernen.
