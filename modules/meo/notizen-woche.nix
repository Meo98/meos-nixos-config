{
  host,
  lib,
  pkgs,
  ...
}: let
  # Wöchentliche Notizenpflege (2026-10-28): Claude Code läuft headless in ~/Notizen,
  # räumt den Eingang auf, verknüpft Neues, führt Stücklisten nach und legt einen
  # Wochenbericht in den Eingang. Darf nur innerhalb ~/Notizen schreiben
  # (acceptEdits gilt nur fürs Arbeitsverzeichnis) und nur die unten erlaubten Befehle.
  # NUR auf meo: zwei gleichzeitige Läufe auf beiden Hosts würden sich über
  # Syncthing gegenseitig Konflikte erzeugen. Verpasste Läufe holt Persistent nach.
  prompt = ''
    Wöchentliche Notizenpflege in ~/Notizen. Es fragt dich niemand zurück – entscheide selbst,
    und was du nicht entscheiden kannst, schreibst du in den Wochenbericht.
    1. Ältere Wochenberichte aus Eingang/ nach Archiv/Wochenberichte/ verschieben (Ordner bei Bedarf anlegen).
    2. Skill `aufraeumen` auf Eingang/ anwenden. Unklare Notizen bleiben im Eingang.
    3. Skill `verknuepfen` auf alle Notizen anwenden, die seit 8 Tagen neu oder geändert sind
       (find -mtime -8), ausser Vorlagen/, Start.md, Wissen/Bauteile.md.
    4. `notizen-bom` ausführen.
    5. Übersicht.md mit dem Stand der Projektnotizen abgleichen (Skill `notiz`, nur die Übersicht).
    6. Wochenbericht schreiben: Eingang/JJJJ-MM-TT Wochenbericht.md (Datum heute), kurz:
       was einsortiert und verknüpft wurde · offene Fragen zu unklaren Notizen · aktive Projekte
       ohne Änderung seit über 30 Tagen (Vorschlag: pausieren?) · offene nächste Schritte der
       aktiven Projekte. Keine Inhalte aus Persönlich/ zitieren oder zusammenfassen.
  '';
  notizen-woche = pkgs.writeShellScriptBin "notizen-woche" ''
    set -eu
    cd "$HOME/Notizen"
    exec /run/current-system/sw/bin/claude -p ${lib.escapeShellArg prompt} \
      --permission-mode acceptEdits \
      --no-session-persistence \
      --allowedTools "Read" "Write" "Edit" "Glob" "Grep" "Skill" \
        "Bash(ls:*)" "Bash(find:*)" "Bash(mv:*)" "Bash(mkdir:*)" "Bash(date:*)" \
        "Bash(grep:*)" "Bash(notizen-bom:*)"
  '';
in {
  home.packages = [notizen-woche];

  systemd.user.services.notizen-woche = lib.mkIf (host == "meo") {
    Unit.Description = "Wöchentliche Notizenpflege mit Claude Code (~/Notizen)";
    Service = {
      Type = "oneshot";
      ExecStart = "${notizen-woche}/bin/notizen-woche";
      # claude braucht PATH für notizen-bom und Standardwerkzeuge
      Environment = "PATH=/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
      TimeoutStartSec = "45min";
    };
  };
  systemd.user.timers.notizen-woche = lib.mkIf (host == "meo") {
    Unit.Description = "Notizenpflege jeden Sonntagabend";
    Timer = {
      OnCalendar = "Sun 18:00";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
