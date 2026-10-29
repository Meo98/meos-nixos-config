{username, ...}: let
  beide = ["meo" "meo-work"];
  mitHandy = beide ++ ["meos-oneplus"];
  # Gelöschte/überschriebene Dateien landen 30 Tage in .stversions statt weg
  papierkorb = {
    type = "trashcan";
    params.cleanoutDays = "30";
  };
in {
  services.syncthing = {
    enable = true; # MODIFIED: Chats/Ordner zwischen meo und meo-work abgleichen
    # MODIFIED: Ports NICHT global öffnen; Syncthing läuft übers Tailscale-Netz,
    # Port 22000 ist nur auf tailscale0 offen (modules/meo/tailscale.nix)
    openDefaultPorts = false;
    user = "${username}";
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";

    # Geräte und Ordner deklarativ, identisch auf beiden Hosts. Der eigene
    # Eintrag wird von Syncthing ignoriert. In der GUI angelegte Ordner/Geräte
    # setzt der Dienst beim Start zurück (overrideDevices/-Folders = Default).
    settings = {
      devices = {
        meo = {
          id = "QJQ5LWC-SDCN4TU-NVPT6LV-4YBO3X2-2SKSJ3E-UGWMN4Q-RLJUCX4-LPZRJQP";
          addresses = ["tcp://meo:22000"]; # MagicDNS übers Tailnet
        };
        meo-work = {
          id = "XVRWHNP-IPU3QYU-7KS3VXU-MCMG7AV-SMV5VZG-PBYFLVY-R4WY2WK-KUSLWAZ";
          addresses = ["tcp://meo-work:22000"];
        };
        # Android (Syncthing-Fork); erreichbar nur, solange Tailscale am Handy läuft
        meos-oneplus = {
          id = "6HJYIY3-FRWKYG5-Q4FAG2C-WP5AKM6-J7W4ISS-M64I7X5-PWB4NAF-CPTKGQY";
          addresses = ["tcp://meos-oneplus:22000"];
        };
      };

      # Nur übers Tailnet verbinden: keine Discovery-/Relay-Server, kein NAT-Mapping
      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
      };

      folders = {
        # Claude-Code-Chats + Memory. NICHT ganz ~/.claude (Tokens/Settings
        # pro Host) und NICHT ~/.claude-mem (SQLite live → Korruption).
        claude-projects = {
          path = "~/.claude/projects";
          devices = mitHandy;
          versioning = papierkorb;
        };
        # Kamera des Handys. Am Handy als "Nur senden" angelegt: Löschen auf
        # den Laptops löscht dort nichts.
        handy-fotos = {
          path = "~/Handy-Fotos";
          devices = mitHandy;
          versioning = papierkorb;
          ignorePatterns = [
            ".trashed-*" # Android-Papierkorb
            ".pending-*" # halb geschriebene Aufnahmen
            "(?d).thumbnails"
          ];
        };
        # Notizen (Markdown, Obsidian-tauglich), Struktur siehe ~/Notizen/Lies mich.md
        notizen = {
          path = "~/Notizen";
          devices = mitHandy;
          versioning = papierkorb;
          ignorePatterns = [
            # Fenster-/Tab-Zustand ist pro Gerät verschieden → sonst Dauerkonflikte
            ".obsidian/workspace*.json"
            ".obsidian/cache"
          ];
        };
        handy-austausch = {
          path = "~/Handy-Austausch";
          devices = mitHandy;
          versioning = papierkorb;
        };
        dokumente = {
          path = "~/Dokumente";
          devices = beide;
          versioning = papierkorb;
          ignorePatterns = [
            "(?d).DS_Store"
            "*~lock~*" # Affinity-Sperrdateien
            ".~lock.*#" # LibreOffice-Sperrdateien
            "(?d)target" # Rust-Builds (Charybdis-RMK ~8 GB), baut jeder Host selbst
            # Seit 2026-10-29 liegen auch die Code-Projekte hier (ehemals ~/Projekte):
            # .git wird mitgesynct, nur Build-/Cache-Ordner raus
            "(?d)node_modules"
            "(?d)__pycache__"
            "(?d).pytest_cache"
            "(?d).venv"
            "(?d)build"
            "result" # nix-build-Symlinks zeigen in den lokalen Store
            "result-*"
          ];
        };
      };
    };
  };
}
