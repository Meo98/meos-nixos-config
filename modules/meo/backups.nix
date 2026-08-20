{
  lib,
  host,
  username,
  ...
}: let
  # Prio 2 — restic-Backups (verschluesselt, versioniert, dedupliziert).
  # Zwei Jobs, siehe docs/superpowers/specs (Backup-Design):
  #   laptop-to-drive : wichtige lokale Ordner -> Google Drive (via rclone).
  #                     Offsite; ueberlebt Laptop-Verlust.
  #   drive-to-local  : lokaler Insync/Drive-Ordner -> internes restic-Repo.
  #                     Schutz gegen versehentliche Drive-Loeschung, die Insync
  #                     sonst lokal propagiert (das Mai-2026-Szenario).
  # RETARGETBAR: `repository` ist ein Parameter — Umzug auf eigenen Server
  # spaeter = nur die repository-Zeile aendern.
  #
  # ===================== EINMALIGER BOOTSTRAP ==========================
  # Backups sind AUS (enableBackups = false in hosts/meo/variables.nix), bis:
  #   1. rclone-Remote 'gdrive' anlegen (Browser-OAuth):
  #        rclone config       # n) new, name: gdrive, storage: drive, Rest default
  #   2. restic-Passwort setzen (frei waehlbar, GUT aufbewahren!):
  #        sudo sh -c 'umask 077; echo "DEIN-STARKES-PASSWORT" > /etc/nixos/restic-password'
  #   3. In hosts/meo/variables.nix: enableBackups = true;
  #   4. fr
  # Danach initialisiert restic beide Repos beim ersten Lauf selbst.
  # =====================================================================
  vars = import ../../hosts/${host}/variables.nix;
  enable = vars.enableBackups or false;

  homeDir = "/home/${username}";
  driveDir = "${homeDir}/Insync/chenevard.romeo@gmail.com/Google Drive";
  passwordFile = "/etc/nixos/restic-password";

  commonExclude = [
    "**/node_modules"
    "**/.direnv"
    "**/target"
    "**/.cache"
    "**/result"
    "**/*.tmp"
  ];
  commonPrune = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6"];
  commonTimer = {
    OnCalendar = "daily";
    Persistent = true;
    RandomizedDelaySec = "1h";
  };
in {
  # Elternordner fuer das lokale drive-to-local-Repo sicherstellen.
  systemd.tmpfiles.rules = lib.mkIf enable [
    "d ${homeDir}/Backups 0700 ${username} users -"
  ];

  services.restic.backups = lib.mkIf enable {
    # --- Offsite: wichtige lokale Ordner -> Google Drive ---------------
    laptop-to-drive = {
      repository = "rclone:gdrive:restic-laptop";
      rcloneConfigFile = "${homeDir}/.config/rclone/rclone.conf";
      inherit passwordFile;
      initialize = true;
      paths = [
        "${homeDir}/Dokumente"
        "${homeDir}/nixos-config"
        "${homeDir}/media-widget"
        # erweitern nach Bedarf (weitere Bastelprojekte).
      ];
      exclude = commonExclude;
      pruneOpts = commonPrune;
      timerConfig = commonTimer;
    };

    # --- Lokal: Insync/Drive-Ordner -> internes versioniertes Repo -----
    drive-to-local = {
      repository = "${homeDir}/Backups/restic-drive";
      inherit passwordFile;
      initialize = true;
      paths = [driveDir];
      exclude = commonExclude;
      pruneOpts = commonPrune;
      timerConfig = commonTimer;
    };
  };
}
