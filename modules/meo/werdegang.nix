{
  lib,
  pkgs,
  ...
}: let
  # Werdegang (2026-10-29): Nach jeder Claude-Code-Sitzung, die Dateien in einem
  # Projektordner geändert hat (Frontmatter `ordner:` der Projektnotiz), schreibt ein
  # headless-Claude einen Eintrag in ~/Notizen/Projekte/<Bereich>/<Projekt>-Werdegang.md:
  # was, warum, Sackgassen, Commits. Die Projektnotiz selbst bleibt kurz (Skill `notiz`).
  #
  # Ablauf: SessionEnd-Hook `werdegang-hook` (registriert in den verwalteten
  # Claude-Einstellungen, siehe modules/meo/claude-werdegang-hook.nix) startet
  # `werdegang` abgelöst im Hintergrund und kehrt sofort zurück. Sitzungen ohne
  # Projektbezug kosten nichts (kein Claude-Aufruf). Log: ~/.local/state/werdegang/log
  prompt = ''
    Du führst den Werdegang von Projekten in ~/Notizen. Auf stdin bekommst du eine gekürzte
    Claude-Code-Sitzung und je betroffenem Projekt die geänderten Dateien und Commits.

    Für JEDES aufgeführte Projekt:
    1. Lies die Projektnotiz, damit du weisst, worum es geht. Sind zwei Projekte mit demselben
       Ordner aufgeführt, ordne die Arbeit dem passenden zu und lass das andere aus, wenn es
       nichts damit zu tun hatte.
    2. Hänge an die Werdegang-Datei (Pfad steht dabei) UNTEN einen Eintrag an. Gibt es die
       Datei nicht, lege sie an mit der Kopfzeile `# Werdegang: <Projekt>`, darunter
       `Wie das Projekt entstanden und gewachsen ist. Ein Eintrag pro Claude-Sitzung, älteste zuerst.
       Kurzfassung und Stand: [[<Projekt>]].` Und füge in der Projektnotiz unter `## Dateien`
       einmalig die Zeile `- Werdegang: [[<Projekt>-Werdegang]]` hinzu (sonst nichts ändern).
    3. Eintrag, Deutsch, knapp, für jemanden, der später verstehen will, wie es dazu kam:
       ## JJJJ-MM-TT · <ein Satz: was erreicht wurde>
       **Ausgangslage:** warum die Sitzung nötig war (1–2 Sätze)
       **Gemacht:** die wichtigen Schritte und Entscheidungen, mit dem Warum (Stichpunkte)
       **Sackgassen:** was nicht ging und warum (nur wenn es welche gab)
       **Offen:** was danach noch fehlte (nur wenn etwas offen blieb)
       **Commits:** Kurz-Hash und Titel (nur wenn welche aufgeführt sind)
       Steht für dieselbe Sitzung (gleiches Datum, gleiches Thema) schon ein Eintrag da,
       ergänze ihn, statt einen zweiten anzulegen.

    Regeln: Nur die Werdegang-Dateien und die eine Zeile in der Projektnotiz anfassen.
    Keine Befehlslisten, keine Pfade ausser wo sie zum Verständnis nötig sind.
    Nie Passwörter, Schlüssel, Tokens, Telefonnummern oder Inhalte aus Persönlich/ übernehmen.
    Nichts erfinden: was nicht in der Sitzung steht, kommt nicht in den Eintrag.
  '';

  werdegang = pkgs.writeShellScriptBin "werdegang" ''
    export WERDEGANG_PROMPT=${lib.escapeShellArg prompt}
    export PATH=/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH
    exec ${pkgs.python3}/bin/python3 -I ${./werdegang/werdegang.py} "$@"
  '';

  # Liest das Hook-JSON von stdin und startet `werdegang` abgelöst (setsid), damit das
  # Beenden von Claude nicht wartet und den Lauf nicht mitreisst.
  werdegang-hook = pkgs.writeShellScriptBin "werdegang-hook" ''
    # vom Werdegang-Lauf selbst gestartete Sitzungen nicht nochmals dokumentieren
    [ -n "''${CLAUDE_WERDEGANG:-}" ] && exit 0
    [ -d "$HOME/Notizen/Projekte" ] || exit 0
    eingabe=$(cat)
    t=$(printf '%s' "$eingabe" | ${pkgs.jq}/bin/jq -r '.transcript_path // empty')
    s=$(printf '%s' "$eingabe" | ${pkgs.jq}/bin/jq -r '.session_id // empty')
    [ -f "$t" ] && [ -n "$s" ] || exit 0
    mkdir -p "$HOME/.local/state/werdegang"
    ${pkgs.util-linux}/bin/setsid -f ${werdegang}/bin/werdegang "$t" "$s" \
      </dev/null >>"$HOME/.local/state/werdegang/log" 2>&1
    exit 0
  '';
in {
  home.packages = [werdegang werdegang-hook];
}
