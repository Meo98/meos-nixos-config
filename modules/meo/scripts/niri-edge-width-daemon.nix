# Setzt Breite und Ausrichtung der fokussierten Spalte nach ihrer Position.
#
#   einzige Spalte im Workspace   100 %   fuellt den Schirm
#   erste oder letzte Spalte      91.667 % buendig am Bildschirmrand,
#                                          die Luecke liegt INNEN beim Nachbarn
#   dazwischen                    83.333 % zentriert
#
# WIE DIE AUSRICHTUNG ZUSTANDE KOMMT. niri kennt keine Aktion "links-" oder
# "rechtsbuendig" — es gibt nur `center-column`. Die Buendigkeit kommt
# deshalb aus layout.nix: center-focused-column = "never" laesst niri die
# Ansicht an den Enden festklemmen, die erste Spalte sitzt damit von selbst
# buendig links und die letzte buendig rechts. Dieser Daemon zentriert dann
# nur noch die MITTLEREN Spalten nach. Beides gehoert zusammen; wer eines
# von beiden aendert, muss das andere mitdenken.
#
# WARUM NICHT ZENTRIEREN UND VERBREITERN. Zentrierung wirkt symmetrisch: ein
# Breitenzuschlag verkleinert den toten Aussenrand und den Guckstreifen nach
# innen im gleichen Mass. Der Rand liesse sich so nur ganz beseitigen, indem
# man die Spalte auf volle Breite zieht — dann ist auch der Nachbar weg. Mit
# Buendigkeit faellt der Aussenrand komplett weg UND der Guckstreifen wird
# groesser (9.3 % statt 8.8 %), weil die ganze Luecke nach innen wandert.
#
# ABSOLUTE STATT RELATIVER BREITEN, MODIFIED 2026-09-09. Die erste Fassung
# rechnete mit Zuschlaegen ("+8.333%"), um nicht mit default-column-width zu
# streiten. Das hatte einen Fehler: der Daemon fuehrte im Arbeitsspeicher
# Buch, welches Fenster welchen Zuschlag traegt. Startete NUR der Daemon neu
# — nach `fr`, nach einem Absturz — war diese Buchhaltung leer, das Fenster
# trug seinen Zuschlag aber noch, und der naechste Fokuswechsel legte ihn ein
# zweites Mal drauf.
#
# Absolute Werte haben das Problem nicht: zweimal dasselbe zu setzen aendert
# nichts. Der Daemon ist damit zustandslos bis auf ein Wiederholungs-Gedaechtnis,
# und das darf gefahrlos verlorengehen.
#
# Dass Prozent hier dasselbe meint wie `proportion` in der Config, ist nicht
# geraten, sondern am laufenden System nachgerechnet (2026-09-09, eDP 1600
# logisch, gaps 8):
#   proportion 0.83333 -> Kachel 1318.1 = 82.38 % des Schirms
#   +8.333 %           -> Kachel 1451.2 = 90.70 %   (= proportion 0.91667)
#   +16.667 %          -> Kachel 1583.1 = 98.95 %   (= proportion 1.0)
# Die Kachel ist jeweils proportion * Breite minus die Luecken. Die Werte
# unten sind daher proportion-Prozente, die sichtbaren Kachelbreiten sind
# 82.38 / 90.70 / 98.95 %.
#
# `decide` ist rein (Zustand + Fensterliste rein, Aktionen raus, kein IPC)
# und wird im Nix-Build per --selftest geprueft. Faellt ein Fall um, bricht
# der Systembau, nicht erst die Sitzung.
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
      """Breite und Ausrichtung der fokussierten Spalte nach ihrer Position."""

      import json
      import os
      import select
      import subprocess
      import sys

      # proportion-Prozente, siehe Kopfkommentar der .nix-Datei.
      WIDTH_SINGLE = os.environ.get("NIRI_EDGE_WIDTH_SINGLE", "100%")
      WIDTH_EDGE = os.environ.get("NIRI_EDGE_WIDTH_EDGE", "91.667%")
      WIDTH_MIDDLE = os.environ.get("NIRI_EDGE_WIDTH_MIDDLE", "83.333%")

      # So lange nach der letzten Ereigniszeile warten, bevor abgefragt wird.
      # Ein Fokuswechsel loest mehrere Ereignisse aus; ohne Sammelfenster
      # gaebe es pro Wechsel mehrere `niri msg`-Aufrufe.
      DEBOUNCE = 0.05


      class State:
          """Nur ein Wiederholungs-Gedaechtnis, keine Buchhaltung.

          last ist (window_id, Spalte, Klasse) des zuletzt behandelten
          Fensters. Geht es verloren, setzt der Daemon dieselben absoluten
          Werte noch einmal — das ist folgenlos. Genau deshalb absolute
          Breiten statt Zuschlaegen.
          """

          def __init__(self):
              self.last = None


      def _column_of(win):
          pos = (win.get("layout") or {}).get("pos_in_scrolling_layout")
          return pos[0] if pos else None


      def classify(snapshot, focused):
          """single | edge | middle — wo steht die fokussierte Spalte?"""
          ws = focused["workspace_id"]
          cols = set()
          for w in snapshot:
              if w["workspace_id"] != ws or w.get("is_floating"):
                  continue
              col = _column_of(w)
              if col is not None:
                  cols.add(col)
          if not cols:
              return None, None
          col = _column_of(focused)
          if len(cols) == 1:
              return "single", col
          if col == min(cols) or col == max(cols):
              return "edge", col
          return "middle", col


      def decide(st, snapshot):
          """Rein: Zustand + Fensterliste -> Aktionen. Kein IPC."""
          focused = next((w for w in snapshot if w.get("is_focused")), None)
          if focused is None:
              return []
          # Schwebende Fenster liegen nicht im Spaltenlayout.
          if focused.get("is_floating") or _column_of(focused) is None:
              return []

          klass, col = classify(snapshot, focused)
          if klass is None:
              return []

          key = (focused["id"], col, klass)
          if key == st.last:
              return []
          st.last = key

          if klass == "single":
              return [("width", WIDTH_SINGLE)]
          if klass == "edge":
              # Kein center: die Buendigkeit macht niri selbst, weil
              # center-focused-column auf "never" steht.
              return [("width", WIDTH_EDGE)]
          # Mitte: erst die Breite, dann zentrieren — umgekehrt wuerde das
          # Zentrieren durch die Breitenaenderung wieder verrutschen.
          return [("width", WIDTH_MIDDLE), ("center",)]


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


      def niri_action(*args):
          subprocess.run(["niri", "msg", "action", *args],
                         check=False,
                         stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)


      def perform(action):
          if action[0] == "width":
              niri_action("set-column-width", action[1])
          elif action[0] == "center":
              niri_action("center-column")


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

          # 1. Einziges Fenster im Workspace -> volle Breite, kein Zentrieren.
          st = State()
          check("einzige Spalte",
                decide(st, [win(1, 1, 1, focused=True)]),
                [("width", WIDTH_SINGLE)])

          # 2. Derselbe Zustand nochmal -> nichts, kein Dauerfeuer.
          check("keine Wiederholung",
                decide(st, [win(1, 1, 1, focused=True)]),
                [])

          # 3. Zweites Fenster dazu: 1 ist jetzt erste von zwei -> Randbreite,
          #    weiterhin kein Zentrieren (niri macht die Buendigkeit).
          check("vom Einzel zum Rand",
                decide(st, [win(1, 1, 1, focused=True), win(2, 1, 2)]),
                [("width", WIDTH_EDGE)])

          # 4. Fokus auf die letzte Spalte -> ebenfalls Randbreite.
          check("letzte Spalte",
                decide(st, [win(1, 1, 1), win(2, 1, 2, focused=True)]),
                [("width", WIDTH_EDGE)])

          # 5. Drei Spalten, Fokus in der Mitte -> schmaler UND zentriert,
          #    in dieser Reihenfolge.
          st2 = State()
          check("Mitte zentriert",
                decide(st2, [win(1, 1, 1), win(2, 1, 2, focused=True),
                             win(3, 1, 3)]),
                [("width", WIDTH_MIDDLE), ("center",)])

          # 6. Kein Drift ueber einen Daemon-Neustart: frischer Zustand,
          #    gleiche Lage -> exakt dieselbe absolute Breite, nicht mehr.
          st3 = State()
          decide(st3, [win(1, 1, 1, focused=True), win(2, 1, 2)])
          st_neu = State()
          check("Neustart ohne Drift",
                decide(st_neu, [win(1, 1, 1, focused=True), win(2, 1, 2)]),
                [("width", WIDTH_EDGE)])

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

          # 9. Andere Workspaces zaehlen nicht mit: Fenster 1 ist trotz
          #    Fenster 2 auf ws 2 die einzige Spalte auf ws 1.
          st6 = State()
          check("Workspaces getrennt",
                decide(st6, [win(1, 1, 1, focused=True), win(2, 2, 1)]),
                [("width", WIDTH_SINGLE)])

          # 10. Vier Spalten: Spalte 2 und 3 sind beide Mitte.
          st7 = State()
          vier = [win(1, 1, 1), win(2, 1, 2, focused=True), win(3, 1, 3),
                  win(4, 1, 4)]
          check("zweite von vier ist Mitte",
                decide(st7, vier),
                [("width", WIDTH_MIDDLE), ("center",)])
          vier2 = [win(1, 1, 1), win(2, 1, 2), win(3, 1, 3, focused=True),
                   win(4, 1, 4)]
          check("dritte von vier ist Mitte",
                decide(st7, vier2),
                [("width", WIDTH_MIDDLE), ("center",)])

          # 11. Schwebende Fenster zaehlen nicht als Spalte: mit einem
          #     schwebenden Nachbarn bleibt Spalte 1 die einzige.
          st8 = State()
          check("schwebender Nachbar zaehlt nicht",
                decide(st8, [win(1, 1, 1, focused=True),
                             win(2, 1, 2, floating=True)]),
                [("width", WIDTH_SINGLE)])

          if fails:
              for f in fails:
                  print("FEHLGESCHLAGEN " + f, file=sys.stderr)
              return 1
          print("selftest: 12 Faelle in Ordnung")
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
