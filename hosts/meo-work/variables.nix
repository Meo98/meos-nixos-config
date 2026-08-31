{
  # Git Configuration
  gitUsername = "Meo98";
  displayName = "Meo";
  gitEmail = "chenevard.romeo@gmail.com";

  # Display Manager
  displayManager = "sddm";

  # Bundled Applications
  tmuxEnable = false;
  alacrittyEnable = false;
  weztermEnable = false;
  ghosttyEnable = true;
  vscodeEnable = false;
  antigravityEnable = false;
  helixEnable = true;
  doomEmacsEnable = false;

  # Hyprland Monitor Settings
  extraMonitorSettings = ''
    # HP Z24n - oben links (per EDID, stabil bei Hot-Plug)
    monitor = desc:Hewlett Packard HP Z24n CN47260BBN,1920x1200@60,0x0,1
    # Dell U2422H - oben rechts (per EDID)
    monitor = desc:Dell Inc. DELL U2422H 9FGXF83,1920x1080@60,1920x0,1
    # LG Laptop - darunter, unter rechtem Monitor, zentriert (per EDID)
    monitor = desc:LG Display 0x06B8,1920x1080@60,2280x1080,1.2
  '';

  # niri-Monitore. Uebersetzt aus extraMonitorSettings oben; Hyprland und niri
  # rechnen beide in LOGISCHEN Koordinaten, die Positionen gehen daher 1:1 auf.
  # Nur die Groesse wird durch die Skalierung geteilt: 1920/1.2 = 1600.
  #
  #   HP Z24n      1920x1200@60, 0x0,       1     ->  1920x1200 bei (0, 0)
  #   Dell U2422H  1920x1080@60, 1920x0,    1     ->  1920x1080 bei (1920, 0)
  #   LG (Laptop)  1920x1080@60, 2280x1080, 1.2   ->  1600x900  bei (2280, 1080)
  #
  # ANSCHLUSSNAMEN SIND EINE ANNAHME. Hyprland adressiert die externen Monitore
  # per EDID (desc:), niri kann beides. Die tatsaechlichen Namen zeigt
  # `niri msg outputs` in einer laufenden niri-Session. Stimmen sie nicht,
  # bleiben die betroffenen Monitore auf niris Automatik-Layout — das ist
  # unschoen, aber nicht kaputt.
  #
  # Umstellung auf EDID spaeter: name = "Dell Inc. DELL U2422H 9FGXF83".
  # Achtung, niris Schreibweise ist NICHT identisch mit Hyprlands desc: bei
  # fehlender Seriennummer haengt niri " Unknown" an.
  niriOutputs = [
    {
      name = "DP-1";
      mode = "1920x1200@60.000";
      scale = 1.0;
      x = 0;
      y = 0;
    }
    {
      name = "DP-2";
      mode = "1920x1080@60.000";
      scale = 1.0;
      x = 1920;
      y = 0;
    }
    {
      name = "eDP-1";
      mode = "1920x1080@60.000";
      scale = 1.2;
      x = 2280;
      y = 1080;
    }
  ];

  # Bar/Shell
  barChoice = "noctalia";

  # Idle-Screen-Off (noctalia): Display bei Inaktivitaet abschalten (660s).
  # meo-work (Tiger Lake, IPS) ist vom eDP-OLED-Freeze auf meo NICHT betroffen
  # -> Screen-off hier wieder aktiv (2026-07-16, vorher pauschal deaktiviert).
  idleScreenOff = true;

  # Waybar Settings
  clock24h = true;

  # Browser (muss in host-packages.nix installiert sein)
  browser = "vivaldi";

  # Terminal
  terminal = "ghostty";

  # Keyboard Layout (Schweizer Deutsch)
  keyboardLayout = "ch";
  consoleKeyMap = "sg";

  # GPU IDs (nicht benötigt für Intel-only, Platzhalter)
  intelID = "PCI:0:2:0";
  amdgpuID = "PCI:0:0:0";
  nvidiaID = "PCI:0:0:0";

  enableAffinity = true;

  # NFS
  enableNFS = true;

  # Drucken
  printEnable = true;

  # Dateimanager
  thunarEnable = false;

  # Wallpaper & Theming
  stylixImage = ../../wallpapers/Anime-Purple-eyes.png;

  waybarChoice = ../../modules/upstream/home/waybar/waybar-ddubs.nix;

  animChoice = ../../modules/upstream/home/hyprland/animations-def.nix;

  # Default Applications (Vivaldi für alles Web-bezogene)
  mimeDefaultApps = {
    # Browser
    "x-scheme-handler/http"         = "vivaldi-stable.desktop";
    "x-scheme-handler/https"        = "vivaldi-stable.desktop";
    "x-scheme-handler/ftp"          = "vivaldi-stable.desktop";
    "x-scheme-handler/chrome"       = "vivaldi-stable.desktop";
    "x-scheme-handler/about"        = "vivaldi-stable.desktop";
    "x-scheme-handler/unknown"      = "vivaldi-stable.desktop";
    "text/html"                     = "vivaldi-stable.desktop";
    "text/xml"                      = "vivaldi-stable.desktop";
    "text/xhtml+xml"                = "vivaldi-stable.desktop";
    "application/xhtml+xml"         = "vivaldi-stable.desktop";
    "application/xml"               = "vivaldi-stable.desktop";
    # PDF
    "application/pdf"               = "onlyoffice-desktopeditors.desktop";
    "application/x-pdf"             = "onlyoffice-desktopeditors.desktop";
  };

  # hostId (muss eindeutig sein, für ZFS)
  hostId = "1d713ceb";
}
