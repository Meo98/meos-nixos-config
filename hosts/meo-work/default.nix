{ config, pkgs, inputs, lib, username, ... }: {
  imports = [
    ./hardware.nix
    ./host-packages.nix
    ./kanata.nix
    ../meo/affinity.nix
  ];

  # Add our custom home-manager modules on top of modules/upstream/home/.
  home-manager.users.${username}.imports = [ ../../modules/meo ];

  programs.kdeconnect.enable = true;

  # --- AUTOMOUNTING ---
  services.udisks2.enable = true;
  environment.systemPackages = [ pkgs.udiskie ];
  systemd.user.services.udiskie = {
    description = "Udiskie Automount Service";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${pkgs.udiskie}/bin/udiskie --no-notify --tray";
  };

  # --- AUDIO FIX (Gegen das Klicken/Knallen) ---
  boot.kernelParams = [ "snd_hda_intel.power_save=0" "snd_hda_intel.power_save_controller=N" ];

  services.pipewire.extraConfig.pipewire."99-disable-suspend" = {
    "context.properties"."node.pause-on-idle" = false;
  };

  # --- WEITERE SERVICES ---
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  services.udev.extraRules = ''
    # Keychron Geräte (Vendor ID 3434)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE="0666", TAG+="uaccess"
    # STM32 Bootloader
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666", TAG+="uaccess"
    # Keychron Link Dongle
    SUBSYSTEM=="usb", ATTRS{idVendor}=="3434", MODE="0666", TAG+="uaccess"
    # Raspberry Pi Pico / Pico W / Pico 2W (MicroPython + BOOTSEL)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2e8a", MODE="0666", TAG+="uaccess"
  '';

  # --- MONITOR LAYOUT NACH SUSPEND WIEDERHERSTELLEN ---
  systemd.services.hyprland-monitor-restore = {
    description = "Restore Hyprland monitor layout after suspend";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "meo";
      Environment = "HYPRLAND_INSTANCE_SIGNATURE=%t/hypr";
      ExecStart = "/bin/sh -c 'sleep 2 && HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/ 2>/dev/null | head -1) hyprctl reload'";
    };
  };

  # --- ZRAM SWAP (verhindert OOM-Kills bei Speicherdruck) ---
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # --- THERMALD (Intel Thermal Management) ---
  services.thermald.enable = true;

  # --- NOATIME auf Root-Partition (reduziert SSD-Schreibzugriffe) ---
  fileSystems."/".options = [ "noatime" ];

  # --- WLAN RFKILL FIX (ideapad_laptop blockiert WLAN wenn Ethernet verbunden) ---
  systemd.services.rfkill-unblock-wifi = {
    description = "Unblock WiFi rfkill on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/rfkill unblock wifi";
      RemainAfterExit = true;
    };
  };

  networking.networkmanager.dispatcherScripts = [{
    source = builtins.toFile "99-wifi-on-ethernet-down" ''
      #!/bin/sh
      INTERFACE="$1"
      ACTION="$2"
      if [ "$ACTION" = "down" ] || [ "$ACTION" = "connectivity-change" ]; then
        /run/current-system/sw/bin/rfkill unblock wifi
      fi
    '';
    type = "basic";
  }];

  # --- DRUCKER ---
  hardware.printers = {
    ensurePrinters = [
      {
        name = "werkstatt";
        location = "Werkstatt";
        # Der Drucker ist ein "Develop ineo+ 450i" (= Konica Minolta bizhub 450i).
        # Erkenntnisse aus Debugging (2026-05-20):
        #   - IPP /ipp + PPD     -> leeres Blatt (IPP-PostScript-Handling kaputt)
        #   - IPP everywhere/PDF -> roher %PDF-Text (PDF-Direct nicht lizenziert)
        #   - Raw-Socket + PPD   -> druckt sauber (Drucker liest rohes PostScript)
        # => Raw-Socket ist der zuverlässige Transport für dieses Gerät.
        # Toner-Status kommt trotzdem (CUPS fragt per SNMP ab, transport-unabhängig).
        deviceUri = "socket://192.168.125.210:9100";
        model = "foomatic-db-ppds/KONICA_MINOLTA-bizhub_C451-Postscript-KONICA_MINOLTA.ppd.gz";
        # PPD-Keyword-Namen (PageSize/Duplex/ColorModel) + CUPS-job-defaults.
        # A3 + fit-to-page als Default, weil die Affinity-Elektropläne im
        # Riesenformat exportiert werden (z.B. 160x90 cm). Ohne fit-to-page
        # druckt CUPS nur eine leere A4/A3-Ecke des Plans (= das berüchtigte
        # "leere Blatt" das uns die ganze IPP-Debugging-Sackgasse beschert hat;
        # siehe docs/TROUBLESHOOTING.md). Mit fit-to-page wird der Plan auf das
        # Blatt skaliert. Alles im GTK-Dialog (yazi Ctrl+P) per-Job umstellbar.
        ppdOptions = {
          PageSize = "A3";                # A3 default — Hauptformat für Pläne
          "fit-to-page-default" = "true";  # übergroße PDFs auf Blatt skalieren
          Duplex = "None";                # Simplex default
          ColorModel = "Color";           # Farbe; im Dialog auf Gray umstellbar
          # InputSlot bewusst weggelassen -> Bizhub Firmware-"Auto Paper Select"
          # wählt das Fach (falls am Bedienfeld aktiviert).
        };
      }
    ];
    ensureDefaultPrinter = "werkstatt";
  };

  # --- BENUTZER & GRUPPEN ---
  users.users."meo".extraGroups = [ "dialout" "input" "uinput" ];

  # --- STANDARD ANWENDUNGEN ---
  # MODIFIED: PDF-Default von onlyoffice auf zathura. Zathura startet in <100ms,
  # hat eingebauten Print-Dialog (Ctrl+P), vim-Keybindings (j/k zum scrollen),
  # und ist ~10x leichter. onlyoffice ist für Editing gemacht, nicht zum
  # schnellen Anschauen.
  xdg.mime.defaultApplications = {
    "text/html" = "vivaldi-stable.desktop";
    "x-scheme-handler/http" = "vivaldi-stable.desktop";
    "x-scheme-handler/https" = "vivaldi-stable.desktop";
    "x-scheme-handler/about" = "vivaldi-stable.desktop";
    "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
    "application/pdf" = "org.pwmt.zathura.desktop";
    "application/x-pdf" = "org.pwmt.zathura.desktop";
  };
}
