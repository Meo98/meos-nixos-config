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
      ];
    };
  };
in
{
  fileSystems = builtins.listToAttrs (map mkShare shares);
  environment.systemPackages = [ pkgs.cifs-utils ];
}
