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
