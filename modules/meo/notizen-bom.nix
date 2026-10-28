{pkgs, ...}: let
  # notizen-bom (2026-10-28): schreibt Stücklisten aus den KiCad-Schaltplänen in die
  # Projektnotizen (~/Notizen, Abschnitt "## Stückliste" zwischen Markern) und erzeugt
  # die Bauteil-Bibliothek ~/Notizen/Wissen/Bauteile.md. Ersetzt die frühere
  # Notion-Synchronisation (scripts/sync_notion.py der Projektvorlage). Logik in
  # ./scripts/notizen-bom.py, nur Python-Standardbibliothek.
  notizen-bom = pkgs.writeShellScriptBin "notizen-bom" ''
    exec ${pkgs.python3}/bin/python3 -I ${./scripts/notizen-bom.py} "$@"
  '';
in {
  home.packages = [notizen-bom];

  # Täglich einmal nachführen. Läuft auf beiden Hosts; das Skript schreibt nur, wenn
  # sich etwas ändert, und die Zufallsverzögerung verhindert, dass beide gleichzeitig
  # dieselbe Datei schreiben (Syncthing-Konflikt).
  systemd.user.services.notizen-bom = {
    Unit.Description = "Stücklisten aus KiCad in ~/Notizen nachführen";
    Service = {
      Type = "oneshot";
      ExecStart = "${notizen-bom}/bin/notizen-bom";
    };
  };
  systemd.user.timers.notizen-bom = {
    Unit.Description = "notizen-bom täglich";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
    Install.WantedBy = ["timers.target"];
  };
}
