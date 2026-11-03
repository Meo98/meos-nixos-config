{username, ...}: {
  # Werdegang-Hook (2026-10-29, Teil von modules/meo/werdegang.nix) als verwaltete
  # Claude-Code-Einstellung. Grund: ~/.claude/settings.json pflegt der User bewusst
  # imperativ (Plugins), home-manager würde sie zur schreibgeschützten Store-Datei machen.
  # Drop-ins in managed-settings.d werden zusammengeführt, und Hooks aus allen Ebenen
  # laufen nebeneinander (Doku: code.claude.com/docs/en/hooks, "merge across settings levels").
  # Der Hook kehrt sofort zurück; die eigentliche Arbeit läuft abgelöst im Hintergrund.
  # Vom User am 2026-10-29 ausdrücklich freigegeben. Abschalten: Import in hosts/*/default.nix entfernen.
  environment.etc."claude-code/managed-settings.d/werdegang.json".text = builtins.toJSON {
    hooks.SessionEnd = [
      {
        hooks = [
          {
            type = "command";
            command = "/etc/profiles/per-user/${username}/bin/werdegang-hook";
            timeout = 10;
          }
        ];
      }
    ];
  };
}
