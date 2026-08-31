{ pkgs, inputs, ... }:
  {
  nixpkgs.overlays = [
    (import ../../modules/meo/bambu.nix)
    (import ../../modules/meo/orcastudio.nix)
    # WIEDER AKTIV 2026-08-31, jetzt mit der eigentlichen Ursache drin:
    # Ghostty klemmt Hi-Res-Scroll-Ticks auf einen ganzen Wheel-Klick hoch
    # (@max(yoff, 1) in scrollCallback(), laut Kommentar dort ein macOS-Workaround).
    # Damit haengt die Scroll-Geschwindigkeit an der Event-Rate des Keyballs
    # statt an der Ballstrecke -> im Terminal um ein Vielfaches zu schnell, und
    # die Geschwindigkeitskurve aus der Firmware ohne jede Wirkung.
    # Der Patch klemmt nur noch auf macOS, hebt den Sub-Zeilen-Rest richtig auf
    # und repariert die x-Achse. Volle Analyse in der Datei selbst.
    (import ../../modules/meo/ghostty-scroll-fix.nix)
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

  # 3. QMK Hardware Support aktivieren
  hardware.keyboard.qmk.enable = true;

  environment.systemPackages = with pkgs; [
    # Screenshots / Clipboard
    grim
    slurp
    swappy
    wl-clipboard
    hyprshot
    jq
    # libnotify — in core/packages.nix
    # --- Multimedia & Kommunikation ---
    audacity                  # Open-Source Audio-Editor für Aufnahme und Bearbeitung
    discord                   # Chat- und Voice-Plattform für Communities/Gaming (hier statt core)
    signal-desktop            # Signal Messenger (kein Web-Wrapper möglich, braucht native App)
    vlc                       # Universeller Medienplayer, spielt fast jedes Videoformat ab
    tidal-hifi                # Desktop-Client für den High-Fidelity Musik-Streamingdienst Tidal
    morgen                    # All-in-one Calendars, Tasks and Scheduler
    orca-slicer               # Open-Source Slicer (Bambu-Studio-Fork), native from-source
    bambu-studio              # Offizieller BambuLab-Slicer (AppImage via modules/meo/bambu.nix overlay)
    orca-studio               # Community-Fork: Bambu Studio + Orca-Features + Cloud-Senden (AppImage via modules/meo/orcastudio.nix overlay)

    # --- Webbrowser ---
    # MODIFIED 2026-07-28: WaylandPerWindowScaling gegen falsch skalierte /
    # fragmentierte erste Frames beim Fensteröffnen (fractional scale 1.6 auf
    # eDP-1): Chromium rendert sonst initial mit Scale 1/2 und der Compositor
    # skaliert die Frames hoch, bis der korrekte Faktor ankommt.
    (vivaldi.override {       # Feature-reicher Browser mit Fokus auf Tab-Management und Privatsphäre
      commandLineArgs = [ "--enable-features=WaylandPerWindowScaling" ];
    })
    google-chrome             # Standard-Browser von Google (oft nötig für DRM/Netflix-Stabilität)
    firefox                   # Der klassische, privatsphäre-orientierte Open-Source Browser

    # --- Produktivität & Office ---
    bitwarden-desktop         # Passwort-Manager zur sicheren Verwaltung deiner Zugangsdaten
    onlyoffice-desktopeditors # Office-Suite mit sehr hoher Kompatibilität zu MS Office-Formaten
    insync                    # Synchronisations-Client für Google Drive und OneDrive
    kicad                     # Professionelles Werkzeug für Elektronik-Design und Platinen-Layout (EDA)
    plasticity                # CAD-Modeler (Direct Modeling, Parasolid-Kernel)
    blender                   # 3D-Suite für Modeling, Sculpting, Animation und Rendering
    # Open-Source Parametrik-CAD (Feature-Tree, STEP); Wayland-Build für Hyprland.
    # Aus separatem Pin nixpkgs-freecad (pdal/vtk auf Haupt-Pin kaputt, s. flake.nix).
    inputs.nixpkgs-freecad.legacyPackages.${pkgs.system}.freecad-wayland
    obsidian                  # Markdown-Note-Editor + Vault für obsidian-stack Projekt

    # --- Entwicklung & System-Tools ---
    nodejs                    # JavaScript-Laufzeitumgebung für Server- und Frontend-Entwicklung
    glab                      # GitLab CLI - Ermöglicht GitLab-Aktionen (wie Login/Push) im Terminal
    distrobox                 # Erlaubt es, andere Linux-Distros (wie Ubuntu/Arch) in Containern zu nutzen
    antigravity               # Ein spezieller Port/Fork für VS Codium/VS Code optimiert
    claude-code               # Anthropic Claude CLI – wird von der Claude Code VS Code-Extension benötigt
    dos2unix                  # Werkzeug zum Umwandeln von Windows-Zeilenumbrüchen in Linux-Format

    # --- Grafik & Gaming ---
    vulkan-tools              # Diagnose-Tools für die Vulkan-Grafik-Schnittstelle (z.B. vulkaninfo)
    # mesa-demos — in core/packages.nix (systemweit verfügbar)
    gamescope                 # Micro-Compositor von Valve für stabileres Gaming und Upscaling
    kdePackages.qtmultimedia  # Multimedia-Bibliotheken für QT-Anwendungen (wichtig für einige Player/UIs)

    # --- Keyboard & Hardware ---
    qmk                       # CLI-Tool zum Flashen von mechanischen Tastaturen mit QMK-Firmware
    vial                      # GUI zur Echtzeit-Konfiguration von Tastatur-Keymaps (Vial-Firmware)
    imv
    procps
    qmk_hid
    hid-listen    

    # --- Keyball Layer Pop-up Tool ---
    (python3.withPackages (ps: with ps; [
      pynput                    # Globales Keyboard-Listening für F13-F16 Layer-Hotkeys
      pillow                    # Bildverarbeitung für Layer-Screenshots
      tkinter                   # GUI für Pop-up-Fenster
      evdev                     # Direkter Zugriff auf Input-Devices (für Wayland)
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
  ];
}
