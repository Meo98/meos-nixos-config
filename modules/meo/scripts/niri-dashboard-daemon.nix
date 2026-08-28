# Liest den niri-Event-Stream und haelt pro Workspace ein Dashboard-Terminal.
#
# Regeln (mit dir am 2026-08-28 festgelegt):
#   - erstes echtes Fenster auf einem Workspace  -> Dashboard starten,
#     nach Spalte 1 schieben, Fokus zurueckgeben
#   - letztes echtes Fenster weg                 -> Dashboard schliessen,
#     damit der Workspace leer wird und verschwindet
#   - Workspace "term" ist ausgenommen (Dropdown-Terminal, Mod+Shift+T)
#
# PYTHON STATT SHELL, BEWUSST: der Daemon fuehrt pro Workspace eine Menge von
# Fenster-IDs. In Bash waeren das assoziative Arrays mit serialisierten Werten
# plus ein jq-Prozess pro Ereignis. Der Rest der Config bleibt bei
# writeShellApplication; hier ueberwiegt die Lesbarkeit.
#
# Die Entscheidungslogik sitzt in `decide` und ist rein: Zustand rein,
# (Zustand, Aktionen) raus, kein IPC. Nur so laesst sie sich im Nix-Build
# testen, ohne dass ein Compositor laufen muesste — siehe --selftest, das in
# der checkPhase ausgefuehrt wird.
{pkgs}: let
  py = pkgs.python3.withPackages (_: []);
in
  pkgs.stdenv.mkDerivation {
    name = "niri-dashboard-daemon";
    dontUnpack = true;

    nativeBuildInputs = [py];

    buildPhase = ''
      cat > niri-dashboard-daemon <<'PYEOF'
      #!${py}/bin/python3
      """Haelt pro niri-Workspace ein Dashboard-Terminal in Spalte 1."""

      import json
      import os
      import subprocess
      import sys

      DASH_APP_ID = "niri-dashboard"
      SKIP_WORKSPACES = {"term"}
      TERMINAL = ["kitty", "--class=" + DASH_APP_ID, "-e", "niri-dashboard"]


      class State:
          """Was der Daemon ueber die Welt weiss.

          real:    workspace_id -> Menge der IDs echter Fenster
          dash:    workspace_id -> ID des Dashboard-Fensters
          pending: workspace_id -> ID des Fensters, das das Dashboard
                   ausgeloest hat und den Fokus zurueckbekommen soll.
                   Dient zugleich als Merker gegen doppelte Starts, wenn
                   zwei Fenster fast gleichzeitig aufgehen.
          names:   workspace_id -> Name (oder None)
          ws_of:   window_id -> workspace_id, um beim Schliessen und beim
                   Verschieben den alten Workspace zu finden
          """

          def __init__(self):
              self.real = {}
              self.dash = {}
              self.pending = {}
              self.names = {}
              self.ws_of = {}

          def is_skipped(self, ws):
              return self.names.get(ws) in SKIP_WORKSPACES


      def forget(st, wid):
          """Fenster aus der Buchfuehrung nehmen, alten Workspace melden."""
          ws = st.ws_of.pop(wid, None)
          if ws is None:
              return None
          st.real.get(ws, set()).discard(wid)
          return ws


      def decide(st, event):
          """Reine Entscheidungsfunktion: Ereignis rein, Aktionsliste raus.

          Aktionen sind Tupel, damit der Selbsttest sie vergleichen kann:
              ("spawn",)               Dashboard-Terminal starten
              ("place", dash, back)    nach Spalte 1, Fokus auf `back`
              ("close", window_id)     Fenster schliessen
          """
          actions = []
          kind, body = next(iter(event.items()))

          if kind == "WorkspacesChanged":
              st.names = {w["id"]: w.get("name") for w in body["workspaces"]}

          elif kind == "WindowsChanged":
              # Vollstaendige Liste — Zustand komplett neu aufbauen. Kommt
              # beim Verbinden und nach einem niri-Neustart unter der Unit.
              st.real, st.dash, st.ws_of = {}, {}, {}
              for w in body["windows"]:
                  _track(st, w)

          elif kind == "WindowOpenedOrChanged":
              w = body["window"]
              old_ws = st.ws_of.get(w["id"])
              new_ws = w["workspace_id"]

              # Verschoben: der alte Workspace kann dadurch leer geworden sein.
              if old_ws is not None and old_ws != new_ws:
                  forget(st, w["id"])
                  actions += _maybe_close(st, old_ws)

              _track(st, w)

              if w.get("app_id") == DASH_APP_ID:
                  back = st.pending.pop(new_ws, None)
                  if back is not None:
                      actions.append(("place", w["id"], back))
              else:
                  actions += _maybe_spawn(st, new_ws, w["id"])

          elif kind == "WindowClosed":
              wid = body["id"]
              ws = st.ws_of.get(wid)
              if ws is not None and st.dash.get(ws) == wid:
                  # Von Hand geschlossen: nicht neu starten, bis der
                  # Workspace einmal leer war.
                  del st.dash[ws]
                  st.ws_of.pop(wid, None)
              else:
                  ws = forget(st, wid)
                  if ws is not None:
                      actions += _maybe_close(st, ws)

          return actions


      def _track(st, w):
          ws = w["workspace_id"]
          st.ws_of[w["id"]] = ws
          if w.get("app_id") == DASH_APP_ID:
              st.dash[ws] = w["id"]
          else:
              st.real.setdefault(ws, set()).add(w["id"])


      def _maybe_spawn(st, ws, trigger):
          if st.is_skipped(ws):
              return []
          if len(st.real.get(ws, set())) != 1:
              return []          # nicht das erste echte Fenster
          if ws in st.dash or ws in st.pending:
              return []          # schon da oder schon unterwegs
          st.pending[ws] = trigger
          return [("spawn",)]


      def _maybe_close(st, ws):
          if st.real.get(ws):
              return []
          st.pending.pop(ws, None)
          dash = st.dash.get(ws)
          return [("close", dash)] if dash is not None else []


      # --------------------------------------------------------------------
      # Ab hier das unreine Aussen: IPC und Prozessstart.
      # --------------------------------------------------------------------

      def niri_action(*args):
          subprocess.run(["niri", "msg", "action", *args],
                         check=False,
                         stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)


      def perform(action):
          if action[0] == "spawn":
              subprocess.Popen(TERMINAL,
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL,
                               start_new_session=True)
          elif action[0] == "place":
              _, dash, back = action
              # move-column-to-index wirkt auf die FOKUSSIERTE Spalte; das
              # Dashboard ist gerade fokussiert, weil es neu aufgegangen ist.
              niri_action("move-column-to-index", "1")
              niri_action("focus-window", "--id", str(back))
          elif action[0] == "close":
              niri_action("close-window", "--id", str(action[1]))


      def run():
          st = State()
          proc = subprocess.Popen(["niri", "msg", "--json", "event-stream"],
                                  stdout=subprocess.PIPE, text=True)
          for line in proc.stdout:
              line = line.strip()
              if not line:
                  continue
              try:
                  event = json.loads(line)
              except json.JSONDecodeError:
                  continue
              for action in decide(st, event):
                  perform(action)
          # Stream zu Ende: niri ist weg. Beenden und von systemd (Restart=
          # always) neu starten lassen, statt hier eine eigene Wiederanlauf-
          # Logik zu pflegen.
          return proc.wait()


      # --------------------------------------------------------------------

      def selftest():
          """Ereignisfolge durchspielen und die erwarteten Aktionen pruefen."""
          st = State()
          fails = []

          def check(label, got, want):
              if got != want:
                  fails.append(f"{label}: {got!r} != {want!r}")

          # Workspace 1 normal, Workspace 9 heisst "term".
          decide(st, {"WorkspacesChanged": {"workspaces": [
              {"id": 1, "name": None}, {"id": 9, "name": "term"}]}})

          def opened(wid, ws, app="ghostty"):
              return {"WindowOpenedOrChanged": {"window": {
                  "id": wid, "workspace_id": ws, "app_id": app}}}

          # 1. Erstes echtes Fenster -> Dashboard starten.
          check("erstes Fenster", decide(st, opened(10, 1)), [("spawn",)])

          # 2. Zweites Fenster waehrend das Dashboard noch unterwegs ist ->
          #    kein zweiter Start.
          check("kein Doppelstart", decide(st, opened(11, 1)), [])

          # 3. Dashboard geht auf -> platzieren, Fokus zurueck auf 10.
          check("platzieren",
                decide(st, opened(99, 1, DASH_APP_ID)),
                [("place", 99, 10)])

          # 4. Ein echtes Fenster schliessen -> nichts, es bleibt eines.
          check("noch belegt",
                decide(st, {"WindowClosed": {"id": 11}}), [])

          # 5. Letztes echtes Fenster schliessen -> Dashboard aufraeumen.
          check("aufraeumen",
                decide(st, {"WindowClosed": {"id": 10}}), [("close", 99)])

          # 6. Workspace "term" bleibt aussen vor.
          check("term ausgenommen", decide(st, opened(20, 9)), [])

          # 7. Letztes Fenster wegschieben statt schliessen -> auch aufraeumen.
          st2 = State()
          decide(st2, {"WorkspacesChanged": {"workspaces": [
              {"id": 1, "name": None}, {"id": 2, "name": None}]}})
          decide(st2, opened(30, 1))
          decide(st2, opened(98, 1, DASH_APP_ID))
          check("verschoben",
                decide(st2, opened(30, 2)),
                [("close", 98), ("spawn",)])

          # 8. Dashboard von Hand geschlossen -> kommt nicht zurueck.
          st3 = State()
          decide(st3, {"WorkspacesChanged": {"workspaces": [{"id": 1, "name": None}]}})
          decide(st3, opened(40, 1))
          decide(st3, opened(97, 1, DASH_APP_ID))
          decide(st3, {"WindowClosed": {"id": 97}})
          check("kein Wiedergaenger", decide(st3, opened(41, 1)), [])

          if fails:
              for f in fails:
                  print("FEHLGESCHLAGEN " + f, file=sys.stderr)
              return 1
          print("selftest: 8 Faelle in Ordnung")
          return 0


      if __name__ == "__main__":
          if "--selftest" in sys.argv:
              sys.exit(selftest())
          sys.exit(run())
      PYEOF
      chmod +x niri-dashboard-daemon
    '';

    # Die reine Logik wird beim Bauen geprueft. Faellt ein Fall um, bricht
    # der Systembau — nicht erst die Session.
    doCheck = true;
    checkPhase = ''
      ${py}/bin/python3 ./niri-dashboard-daemon --selftest
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp niri-dashboard-daemon $out/bin/
    '';
  }
