# Verbreitert die fokussierte Spalte, wenn sie am Rand ihres Workspace steht.
#
# WARUM ES DAS BRAUCHT. layout.nix setzt center-focused-column = "always";
# die fokussierte Spalte sitzt also immer mittig, links und rechts bleiben bei
# 5/6 Arbeitsbreite je (1 - 5/6)/2 = 1/12 des Schirms. In der Mitte zeigen
# diese Streifen die Nachbarspalten — am ERSTEN und am LETZTEN Fenster ist auf
# der Aussenseite aber kein Nachbar, dort steht der Streifen leer. niris Autor
# laesst das bewusst so (Diskussion niri-wm/niri#1642: "I occasionally need and
# want empty space on the right"), es ist also kein Fehler, den niri irgendwann
# behebt.
#
# RELATIVE STATT ABSOLUTER BREITEN, BEWUSST. `set-column-width "91%"` waere
# einfacher, wuerde aber mit zwei Dingen streiten: mit default-column-width aus
# layout.nix (Prozent und `proportion` rechnen die gaps unterschiedlich ein,
# die Ruecksetzung landete also ~15 px neben dem Config-Wert) und mit jeder
# Breite, die man selbst per Mod+R eingestellt hat. Die relative Form
# ("+8.333%") ist laut default-config.kdl ein Anteil der BILDSCHIRMbreite und
# geht damit exakt hin und zurueck, egal von welchem Ausgangswert.
#
# DIE ZAHLEN. Weil zentriert wird, wirkt ein Zuschlag symmetrisch: +8.333%
# halbiert den toten Aussenrand UND den Guckstreifen nach innen. Es gibt daher
# nur zwei sinnvolle Punkte:
#   einzige Spalte im Workspace -> +16.667% (= volle Breite; es gibt keinen
#                                  Nachbarn, also nichts zu verlieren)
#   erste oder letzte von mehreren -> +8.333% (haelfte des toten Randes, der
#                                  Guckstreifen bleibt halb erhalten)
# Beides steht in edge-width.nix als Environment und laesst sich dort aendern.
#
# KEINE EREIGNISNAMEN. Der Daemon wertet den Event-Stream nicht aus, sondern
# nimmt jede Zeile nur als "irgendwas hat sich bewegt", sammelt kurz und fragt
# dann einmal `niri msg --json windows`. Das ist robust gegen neue oder
# umbenannte Ereignisse in kommenden niri-Versionen — die Namen aus dem Binary
# zu lesen war nicht moeglich, sie liegen dort nur als Symbolsalat vor.
#
# Wie beim frueheren Dashboard-Daemon: `decide` ist rein (Zustand + Fensterliste
# rein, Aktionen raus, kein IPC) und wird im Nix-Build per --selftest geprueft.
# Faellt ein Fall um, bricht der Systembau, nicht erst die Sitzung.
{pkgs}: let
  py = pkgs.python3.withPackages (_: []);
in
  pkgs.stdenv.mkDerivation {
    name = "niri-edge-width-daemon";
    dontUnpack = true;

    nativeBuildInputs = [py];

    buildPhase = ''
      cat > niri-edge-width-daemon <<'PYEOF'
      #!${py}/bin/python3
      """Verbreitert die fokussierte Spalte am Rand des Workspace."""

      import json
      import os
      import select
      import subprocess
      import sys

      # Zuschlaege in Prozent der Bildschirmbreite.
      BONUS_SINGLE = float(os.environ.get("NIRI_EDGE_BONUS_SINGLE", "16.667"))
      BONUS_EDGE = float(os.environ.get("NIRI_EDGE_BONUS_EDGE", "8.333"))

      # So lange nach der letzten Ereigniszeile warten, bevor abgefragt wird.
      # Ein Fokuswechsel loest mehrere Ereignisse aus; ohne Sammelfenster
      # gaebe es pro Wechsel mehrere `niri msg`-Aufrufe.
      DEBOUNCE = 0.05


      class State:
          """applied: window_id -> Zuschlag, der auf diesem Fenster liegt.

          Der Zuschlag klebt am FENSTER, nicht an der Spaltenposition. Ein
          Fenster, das den Rand verlaesst, waehrend ein anderes fokussiert
          ist, behaelt seinen Zuschlag zunaechst — set-column-width wirkt nur
          auf die fokussierte Spalte, wir koennen es also gar nicht sofort
          korrigieren. Beim naechsten Fokussieren wird es nachgezogen.
          """

          def __init__(self):
              self.applied = {}


      def _column_of(win):
          pos = (win.get("layout") or {}).get("pos_in_scrolling_layout")
          return pos[0] if pos else None


      def desired_bonus(snapshot, focused):
          """Welcher Zuschlag steht dem fokussierten Fenster zu?"""
          ws = focused["workspace_id"]
          cols = set()
          for w in snapshot:
              if w["workspace_id"] != ws or w.get("is_floating"):
                  continue
              col = _column_of(w)
              if col is not None:
                  cols.add(col)
          if not cols:
              return 0.0
          col = _column_of(focused)
          if len(cols) == 1:
              return BONUS_SINGLE
          if col == min(cols) or col == max(cols):
              return BONUS_EDGE
          return 0.0


      def decide(st, snapshot):
          """Rein: Zustand + Fensterliste -> Aktionen. Kein IPC."""
          live = {w["id"] for w in snapshot}
          for wid in [w for w in st.applied if w not in live]:
              del st.applied[wid]

          focused = next((w for w in snapshot if w.get("is_focused")), None)
          if focused is None:
              return []
          # Schwebende Fenster liegen nicht im Spaltenlayout.
          if focused.get("is_floating") or _column_of(focused) is None:
              return []

          want = desired_bonus(snapshot, focused)
          have = st.applied.get(focused["id"], 0.0)
          delta = round(want - have, 3)
          if abs(delta) < 0.001:
              return []
          st.applied[focused["id"]] = want
          return [("set-width", delta)]


      # --------------------------------------------------------------------
      # Ab hier das unreine Aussen: IPC.
      # --------------------------------------------------------------------

      def snapshot():
          out = subprocess.run(["niri", "msg", "--json", "windows"],
                               capture_output=True, text=True, check=False)
          if out.returncode != 0:
              return None
          try:
              return json.loads(out.stdout)
          except json.JSONDecodeError:
              return None


      def perform(action):
          if action[0] == "set-width":
              subprocess.run(
                  ["niri", "msg", "action", "set-column-width",
                   "{0:+.3f}%".format(action[1])],
                  check=False,
                  stdout=subprocess.DEVNULL,
                  stderr=subprocess.DEVNULL)


      def run():
          st = State()
          proc = subprocess.Popen(["niri", "msg", "--json", "event-stream"],
                                  stdout=subprocess.PIPE)
          fd = proc.stdout.fileno()

          # Einmal zu Beginn, damit ein Neustart des Daemons den aktuellen
          # Zustand sofort herstellt statt erst beim naechsten Ereignis.
          pending = True
          timeout = DEBOUNCE

          while True:
              ready, _, _ = select.select([fd], [], [], timeout)
              if ready:
                  chunk = os.read(fd, 65536)
                  if not chunk:
                      break  # Stream zu Ende: niri ist weg.
                  # Der Inhalt interessiert nicht, nur dass sich etwas regte.
                  pending = True
                  timeout = DEBOUNCE
                  continue
              if pending:
                  pending = False
                  snap = snapshot()
                  if snap is not None:
                      for action in decide(st, snap):
                          perform(action)
              timeout = None if not pending else DEBOUNCE

          # systemd startet neu (Restart=always), statt hier eigene
          # Wiederanlauf-Logik zu pflegen.
          return proc.wait()


      # --------------------------------------------------------------------

      def selftest():
          """Zustandsfolgen durchspielen und die Aktionen pruefen."""
          fails = []

          def check(label, got, want):
              if got != want:
                  fails.append("{0}: {1!r} != {2!r}".format(label, got, want))

          def win(wid, ws, col, focused=False, floating=False):
              return {"id": wid, "workspace_id": ws, "is_focused": focused,
                      "is_floating": floating,
                      "layout": {"pos_in_scrolling_layout": [col, 1]}}

          # 1. Einziges Fenster im Workspace -> voller Zuschlag.
          st = State()
          check("einzige Spalte",
                decide(st, [win(1, 1, 1, focused=True)]),
                [("set-width", BONUS_SINGLE)])

          # 2. Derselbe Zustand nochmal -> nichts, kein Dauerfeuer.
          check("keine Wiederholung",
                decide(st, [win(1, 1, 1, focused=True)]),
                [])

          # 3. Zweites Fenster kommt dazu: 1 ist jetzt erste von zwei, also
          #    nur noch der halbe Zuschlag -> Differenz nach unten.
          check("vom Einzel zum Rand",
                decide(st, [win(1, 1, 1, focused=True), win(2, 1, 2)]),
                [("set-width", round(BONUS_EDGE - BONUS_SINGLE, 3))])

          # 4. Fokus auf die letzte Spalte -> die bekommt den Randzuschlag.
          check("letzte Spalte",
                decide(st, [win(1, 1, 1), win(2, 1, 2, focused=True)]),
                [("set-width", BONUS_EDGE)])

          # 5. Drei Spalten, Fokus in der Mitte -> gar kein Zuschlag.
          st2 = State()
          check("Mitte ohne Zuschlag",
                decide(st2, [win(1, 1, 1), win(2, 1, 2, focused=True),
                             win(3, 1, 3)]),
                [])

          # 6. Ein Fenster, das den Rand verlaesst, wird beim naechsten
          #    Fokussieren nachgezogen (Zuschlag muss wieder weg).
          st3 = State()
          decide(st3, [win(1, 1, 1, focused=True), win(2, 1, 2)])
          check("Nachziehen beim Fokussieren",
                decide(st3, [win(9, 1, 1), win(1, 1, 2, focused=True),
                             win(2, 1, 3)]),
                [("set-width", -BONUS_EDGE)])

          # 7. Schwebendes Fenster fokussiert -> Finger weg.
          st4 = State()
          check("schwebend ignorieren",
                decide(st4, [win(1, 1, 1, focused=True, floating=True)]),
                [])

          # 8. Fenster ohne Spaltenposition (z. B. gerade erst geoeffnet).
          st5 = State()
          check("ohne Spaltenposition",
                decide(st5, [{"id": 1, "workspace_id": 1, "is_focused": True,
                              "layout": {"pos_in_scrolling_layout": None}}]),
                [])

          # 9. Geschlossenes Fenster faellt aus der Buchhaltung.
          st6 = State()
          decide(st6, [win(1, 1, 1, focused=True)])
          decide(st6, [win(2, 2, 1, focused=True)])
          if 1 in st6.applied:
              fails.append("Buchhaltung: Fenster 1 haengt nach dem Schliessen fest")

          # 10. Andere Workspaces zaehlen nicht mit: Fenster 1 ist trotz
          #     Fenster 2 auf ws 2 die einzige Spalte auf ws 1.
          st7 = State()
          check("Workspaces getrennt",
                decide(st7, [win(1, 1, 1, focused=True), win(2, 2, 1)]),
                [("set-width", BONUS_SINGLE)])

          if fails:
              for f in fails:
                  print("FEHLGESCHLAGEN " + f, file=sys.stderr)
              return 1
          print("selftest: 10 Faelle in Ordnung")
          return 0


      if __name__ == "__main__":
          if "--selftest" in sys.argv:
              sys.exit(selftest())
          sys.exit(run())
      PYEOF
      chmod +x niri-edge-width-daemon
    '';

    doCheck = true;
    checkPhase = ''
      ${py}/bin/python3 ./niri-edge-width-daemon --selftest
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp niri-edge-width-daemon $out/bin/
    '';
  }
