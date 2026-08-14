{ pkgs, lib, ... }:

let
  # Synology "edisrv" — DSM erreichbar unter https://172.17.200.10:15001.
  # Freigaben werden per CIFS/SMB gemountet, damit Dateien direkt bearbeitet
  # werden können statt download → edit → upload über File Station.
  nas = "172.17.200.10";

  # Eine Zeile pro Freigabe; gemountet nach /mnt/edisrv/<name>.
  shares = [
    # "web" braucht erst Lesen/Schreiben-Berechtigung in DSM
    # (Systemsteuerung → Freigegebener Ordner → web → Berechtigungen),
    # sonst schlägt der Mount mit Permission denied fehl.
    "edi"
    "public"
    "temp"
  ];

  # Credentials liegen BEWUSST außerhalb des Repos (fr auto-committed alles
  # nach GitHub). Datei-Format:
  #   username=<synology-user>
  #   password=<passwort>
  # Anlegen mit: sudo install -m 600 /dev/null /etc/nixos/smb-secrets && sudoedit /etc/nixos/smb-secrets
  credentials = "/etc/nixos/smb-secrets";

  # systemd-Unit-Namen zu den Mountpoints (/mnt/edisrv/<share> → mnt-edisrv-<share>).
  automountUnits = map (share: "mnt-edisrv-${share}.automount") shares;
  mountUnits = map (share: "mnt-edisrv-${share}.mount") shares;

  mkShare = share: {
    name = "/mnt/edisrv/${share}";
    value = {
      device = "//${nas}/${share}";
      fsType = "cifs";
      options = [
        "credentials=${credentials}"
        "uid=1000"
        "gid=100"
        # Automount statt Boot-Mount: verbindet erst beim ersten Zugriff und
        # blockiert weder Boot noch Shutdown, wenn die NAS nicht erreichbar ist.
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=300"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "_netdev"
        "vers=3.1.1"
        "iocharset=utf8"
        # CIFS ist per Default "hard": I/O und Unmount hängen UNBEGRENZT in
        # D-State, wenn die NAS wegfällt (z.B. WLAN stirbt beim Suspend).
        # Solche Prozesse kann der cgroup-Freezer weder einfrieren noch
        # auftauen — Folge war 2026-08-14 zweimal "Failed to thaw unit
        # 'user.slice'" nach Resume: komplette Session eingefroren, nur noch
        # blinkender VT-Cursor, Hard-Reboot nötig. "soft" lässt Requests nach
        # den Reconnect-Versuchen fehlschlagen statt ewig zu blockieren;
        # echo_interval=15 erkennt den Serververlust nach ~30s statt ~120s.
        "soft"
        "echo_interval=15"
        # Byte-Range-Locks nicht zum SMB-Server durchreichen (nur lokal).
        # Ohne das halten OnlyOffice/LibreOffice Dateien auf dem Mount für
        # gesperrt und erlauben nur "Speichern unter" statt Ctrl+S in-place.
        "nobrl"
      ];
    };
  };
in
{
  fileSystems = builtins.listToAttrs (map mkShare shares);
  environment.systemPackages = [ pkgs.cifs-utils ];

  # Ist die NAS nicht erreichbar (anderes Netz, NAS aus), lassen fehlgeschlagene
  # Mount-Versuche die autofs-Punkte in einem Zustand zurück, an dem bwrap beim
  # rekursiven Bind-Mount von /mnt hart scheitert ("No such device") — sandboxed
  # Apps (FHS-Wrapper wie Bambu Studio, Flatpaks) starten dann nicht mehr, und
  # nh-Aktivierungen enden wegen der failed Units mit Exit 4. Deshalb schaltet
  # dieser Dispatcher die Automounts bei jedem Netzwechsel passend: SMB-Port der
  # NAS erreichbar → Automounts an, sonst alles stoppen + failed-State resetten.
  # Suspend darf nie mit aktivem CIFS-Mount passieren: insync pollt
  # /mnt/edisrv/* im Sekundentakt und hält die Mounts damit praktisch immer
  # aktiv. Klappte der Deckel zu, starb das WLAN unter dem aktiven Mount und
  # die hängenden Unmount-Jobs verklemmten PID 1 so, dass user.slice nach dem
  # Resume nicht mehr aufgetaut wurde (Journal 2026-08-14: "Failed to thaw
  # unit 'user.slice': Connection timed out" → Session eingefroren,
  # Hard-Reboot). Deshalb: vor sleep.target aushängen, solange das Netz noch
  # steht. Nach dem Resume schaltet der NM-Dispatcher unten die Automounts
  # beim Netz-up-Event wieder ein.
  systemd.services.edisrv-unmount-before-sleep = {
    description = "edisrv-CIFS-Shares vor dem Suspend aushängen";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Falls doch etwas hängt: Suspend nach 15s trotzdem zulassen.
      TimeoutStartSec = 15;
      ExecStart = pkgs.writeShellScript "edisrv-unmount-before-sleep" ''
        systemctl=/run/current-system/sw/bin/systemctl
        ${pkgs.coreutils}/bin/timeout 10 $systemctl stop \
          ${lib.escapeShellArgs (automountUnits ++ mountUnits)} || true
        # Hängengebliebene Mounts notfalls lazy+force austragen.
        for share in ${lib.escapeShellArgs shares}; do
          if ${pkgs.util-linux}/bin/findmnt -t cifs "/mnt/edisrv/$share" > /dev/null; then
            ${pkgs.util-linux}/bin/umount -l -f "/mnt/edisrv/$share" || true
          fi
        done
        $systemctl reset-failed 'mnt-edisrv-*' 2> /dev/null || true
      '';
    };
  };

  # Sicherheitsnetz hinter den beiden Fixes oben: systemd (seit v254) friert
  # user.slice über Suspend ein; genau dieses Auftauen ist am 2026-08-14
  # zweimal fehlgeschlagen. Ohne Einfrieren laufen User-Prozesse über den
  # Suspend einfach weiter (Verhalten wie vor systemd 254) — selbst wenn ein
  # Mount doch mal hängt, bleibt die Session dann bedienbar.
  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "edisrv-automounts" ''
        case "$2" in
          up | down | connectivity-change | vpn-up | vpn-down) ;;
          *) exit 0 ;;
        esac

        systemctl=/run/current-system/sw/bin/systemctl
        if ${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash \
          -c ': < /dev/tcp/${nas}/445' 2> /dev/null; then
          $systemctl start ${lib.escapeShellArgs automountUnits}
        else
          $systemctl stop ${lib.escapeShellArgs (automountUnits ++ mountUnits)}
          $systemctl reset-failed ${lib.escapeShellArgs (automountUnits ++ mountUnits)} 2> /dev/null || true
        fi
      '';
    }
  ];
}
