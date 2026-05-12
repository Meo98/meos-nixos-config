{ pkgs, inputs, ... }:
  {
  nixpkgs.overlays = [
    (import ../../modules/core/bambu.nix)
    # oder wenn im Repo relativ:
    # (import ../overlays/bambu.nix)
  ];

  services.flatpak.enable = true; # Ermöglicht die Installation von Flatpaks (GUI-Apps außerhalb des Nix-Stores)


  # 2. QMK & Vial Berechtigungen (Udev Rules)
  # Dies erlaubt dir, ohne 'sudo' zu flashen und Vial zu nutzen
  services.udev.packages = [ 
    pkgs.vial 
    pkgs.qmk-udev-rules 
  ];

  environment.systemPackages = with pkgs; [
    # Screenshots / Clipboard (grim/slurp/swappy/wl-clipboard/hyprshot bereits in hyprland.nix)
    jq
    libnotify
    zip
    unzip
    glow
    # --- Multimedia & Kommunikation ---
    audacity                  # Open-Source Audio-Editor für Aufnahme und Bearbeitung
    discord                   # Chat- und Voice-Plattform für Communities/Gaming
    vlc                       # Universeller Medienplayer, spielt fast jedes Videoformat ab
    tidal-hifi                # Desktop-Client für den High-Fidelity Musik-Streamingdienst Tidal
    morgen                    # All-in-one Calendars, Tasks and Scheduler
    orca-slicer

    # --- Webbrowser ---
    vivaldi                   # Feature-reicher Browser mit Fokus auf Tab-Management und Privatsphäre

    # --- Produktivität & Office ---
    signal-desktop            # Signal Messenger (kein Web-Wrapper möglich, braucht native App)
    bitwarden-desktop         # Passwort-Manager zur sicheren Verwaltung deiner Zugangsdaten
    onlyoffice-desktopeditors # Office-Suite mit sehr hoher Kompatibilität zu MS Office-Formaten
    insync                    # Synchronisations-Client für Google Drive und OneDrive
    masterpdfeditor           # PDF-Editor mit Annotationen, Formularen und Seitenbearbeitung (PDF-XChange-Alternative)
    kicad                     # Professionelles Werkzeug für Elektronik-Design und Platinen-Layout (EDA)

    # --- Entwicklung & System-Tools ---
    nodejs                    # JavaScript-Laufzeitumgebung für Server- und Frontend-Entwicklung
    glab                      # GitLab CLI - Ermöglicht GitLab-Aktionen (wie Login/Push) im Terminal
    distrobox                 # Erlaubt es, andere Linux-Distros (wie Ubuntu/Arch) in Containern zu nutzen
    antigravity               # Ein spezieller Port/Fork für VS Codium/VS Code optimiert
    dos2unix                  # Werkzeug zum Umwandeln von Windows-Zeilenumbrüchen in Linux-Format
    claude-code
    ferdium

    # --- Grafik & Gaming ---
    vulkan-tools              # Diagnose-Tools für die Vulkan-Grafik-Schnittstelle (z.B. vulkaninfo)
    mesa-demos                # Enthält Tools wie glxinfo, um die GPU-Beschleunigung zu prüfen
    gamescope                 # Micro-Compositor von Valve für stabileres Gaming und Upscaling
    kdePackages.qtmultimedia  # Multimedia-Bibliotheken für QT-Anwendungen (wichtig für einige Player/UIs)

    # --- Keyboard & Hardware ---
    qmk                       # CLI-Tool zum Flashen von mechanischen Tastaturen mit QMK-Firmware
    vial                      # GUI zur Echtzeit-Konfiguration von Tastatur-Keymaps (Vial-Firmware)
    imv
    procps
    qmk_hid
    hid-listen    

    # --- Keyball Layer Pop-up Tool + MicroPython Tools ---
    (python3.withPackages (ps: with ps; [
      pynput                    # Globales Keyboard-Listening für F13-F16 Layer-Hotkeys
      pillow                    # Bildverarbeitung für Layer-Screenshots
      tkinter                   # GUI für Pop-up-Fenster
      evdev                     # Direkter Zugriff auf Input-Devices (für Wayland)
      mpremote                  # MicroPython Remote Tool für Raspberry Pi Pico
    ]))

    # --- Custom Desktop Items (Web-Apps) ---
    # Erstellt einen Menü-Eintrag, der Microsoft 365 als "App" (Web-Wrapper) über Vivaldi startet
    (makeDesktopItem {
      name = "ms-office-365";
      desktopName = "Microsoft 365";
      exec = "${pkgs.vivaldi}/bin/vivaldi --app=\"https://www.office.com/?auth=2\"";
      icon = "vivaldi";
      categories = [ "Office" ];
    })
    
    # --- Platzhalter für optionale v2 (Affinity Suite via Nix) ---
    # inputs.affinity-nix.packages.${pkgs.system}.designer
    # inputs.affinity-nix.packages.${pkgs.system}.photo
    # inputs.affinity-nix.packages.${pkgs.system}.publisher
    
    # --- Windows VM Container ---
    winboat
    freerdp
  ];
}
