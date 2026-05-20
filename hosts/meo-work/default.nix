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
        # MODIFIED: socket://...:9100 (Raw JetDirect) -> ipp://...
        # WICHTIG: Der Drucker an dieser IP ist ein "Develop ineo+ 450i"
        # (= Konica Minolta bizhub 450i, ~2020). Sein IPP-Endpunkt ist /ipp
        # (NICHT /ipp/print wie IPP-Everywhere — das gibt client-error-not-found).
        # Verifiziert via: ipptool -tv ipp://192.168.125.210/ipp get-printer-attributes.test
        # IPP liefert Job-Status, Toner-Levels, Paper-Out-Detection.
        # Fallback falls IPP-Druck nicht klappt: socket://192.168.125.210:9100
        deviceUri = "ipp://192.168.125.210/ipp";
        model = "foomatic-db-ppds/KONICA_MINOLTA-bizhub_C451-Postscript-KONICA_MINOLTA.ppd.gz";
        # MODIFIED: erweiterte Defaults für Office-Use. Alle Werte sind im
        # GTK-Print-Dialog (yazi Ctrl+P) per-Job überschreibbar.
        # Alternativen für Duplex: "None" (Simplex), "DuplexNoTumble" (Long-Edge
        # für Briefe), "DuplexTumble" (Short-Edge für Querformat-Pläne).
        ppdOptions = {
          PageSize = "A4";
          Duplex = "None";          # Simplex default — Pläne werden meist einseitig in Ordner abgeheftet
          ColorModel = "Color";     # Farbdruck als default; im Dialog auf Gray umstellbar
          # InputSlot bewusst NICHT gesetzt → Bizhub Firmware-Setting "Auto Paper
          # Select" wählt das passende Fach basierend auf PageSize. Voraussetzung:
          # Am Bedienfeld muss Tray-Bestückung korrekt konfiguriert sein
          # (z.B. Tray1=A4, Tray2=A3) und "Papier-Wahl = AUTO" aktiviert sein.
          # Vorteil: Papier-Sorte in den Trays umstellbar ohne NixOS-Rebuild.
          # Falls Bedienfeld nicht auf Auto: Drucker nutzt seinen FW-Default-Tray.

          # Weitere Konica-bizhub-C451 PPD-Optionen falls nötig:
          # Collate = "True"; OutputBin = "Default"; Binding = "LeftBinding";
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
