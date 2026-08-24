{ pkgs, ... }: {
  programs.tealdeer = {
    enable = true;
    settings = {
      display.compact = false;
      display.use_pager = true;
      updates.auto_update = true;
    };
  };

  # MODIFIED: tldr-update.service lief per Persistent-Timer direkt nach dem Boot,
  # bevor DNS bereit war -> "failed to lookup address information" -> Unit FAILED
  # (vom Automations-Wächter zurecht als fail gemeldet, 10./17./24.08.). tldr
  # selbst funktioniert mit dem vorhandenen Cache weiter, nur das Update platzt.
  # Fix: ExecStartPre wartet bis zu ~90 s auf Konnektivität (bricht NIE hart ab,
  # endet immer mit `true`); nur ein echt offline gebliebenes Gerät lässt das
  # eigentliche Update dann noch scheitern, was korrekt ist.
  systemd.user.services.tldr-update.Service = {
    ExecStartPre =
      "${pkgs.bash}/bin/bash -c 'for i in {1..12}; do "
      + "${pkgs.curl}/bin/curl -sfI -o /dev/null --max-time 4 https://github.com && break; "
      + "${pkgs.coreutils}/bin/sleep 4; done; true'";
    TimeoutStartSec = 150;
  };
}
