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

  # MODIFIED 2026-06-12: hypridle Auto-Start kappen — Noctalia v5 macht idle
  # alleine, sonst race. Siehe Begründung in hosts/meo/default.nix.
  systemd.user.services.hypridle.wantedBy = lib.mkForce [];

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
    # Microchip ICD3 In-Circuit Debugger (PIC18F4520 / StroboGlas). Ganze VID,
    # da der ICD3 nach dem Firmware-Load seine PID wechselt (Boot 0x9009 -> Runtime).
    SUBSYSTEM=="usb", ATTRS{idVendor}=="04d8", MODE="0666", TAG+="uaccess"
  '';

  # MPLAB X IDE (Java/NetBeans-Swing) + XC8 ueber nix-ld lauffaehig machen.
  # Diese Liste MERGT mit der Basisliste in modules/upstream/core/packages.nix.
  # Host-lokal -> meo (Trading-Bot) bleibt unveraendert.
  programs.nix-ld.libraries = with pkgs; [
    gtk2
    gtk3
    cairo
    pango
    gdk-pixbuf
    atk
    at-spi2-core
    at-spi2-atk
    nss
    nspr
    cups
    libxkbcommon
    xorg.libXtst
    xorg.libXt
    xorg.libXxf86vm
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXScrnSaver
    xorg.libXft
    xorg.libXinerama
  ];

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
  # Bei 16 GB RAM + Affinity (unter Wine, ~5-10 GB RSS) ist der Speicher der
  # harte Engpass. zram = komprimierter RAM-Swap (zstd ~3-5:1). 50% logisch
  # ≈ 8 GB Swap, kostet real nur ~1.5-2 GB RAM. Füllt sich VOR der Disk-Swap
  # (zram-generator setzt swap-priority=5).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;   # war 25 — verdoppelt, da RAM der harte Engpass ist
  };

  # --- DISK-SWAP als Überlauf hinter zram (Notnetz gegen OOM-Kills) ---
  # Wenn zram voll ist, lagert der Kernel kalte Seiten hierher aus, statt
  # Affinity per OOM-Killer abzuschiessen (siehe 25.06.: Affinity bei 9.7 GB
  # RSS gekillt). 8 GB reichen als Puffer; Root hat ~48 GB frei. ext4 -> simple
  # Swap-Datei, niedrigere Prio als zram -> nur Überlauf.
  swapDevices = [{
    device = "/swapfile";
    size = 8 * 1024;   # 8 GiB
  }];

  # --- KERNEL-VM-TUNING (knapper RAM + schnelles zstd-zram) ---
  # Merged mit vm.max_map_count aus modules/upstream/core/boot.nix.
  boot.kernel.sysctl = {
    # zram ist schnell -> aggressiv auslagern statt File-Cache wegzuwerfen.
    "vm.swappiness" = 150;
    # zram mag Einzelseiten (kein Read-ahead beim Swap-In).
    "vm.page-cluster" = 0;
    # Dentry/Inode-Cache länger halten -> snappigere Dateioperationen.
    "vm.vfs_cache_pressure" = 50;
    # Früher Speicher zurückfordern -> weniger plötzliche Stalls/OOM unter Druck.
    "vm.watermark_scale_factor" = 125;
    # Sanftere Writeback-Schübe auf der einzelnen SSD (weniger I/O-Stalls).
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };

  # --- THERMALD (Intel Thermal Management) ---
  services.thermald.enable = true;

  # --- BUILD-LAST ZÄHMEN (schützt offene Apps vor dem OOM-Killer) ---
  # Am 30.06. 08:52 hat der Kernel-OOM-Killer Affinity (4.8 GB, oom_score_adj
  # 200 = bevorzugtes Opfer) abgeschossen, weil ein Hintergrund-Rebuild
  # (Noctalia/Wine aus Source) den RAM auf 16 GB sprengte. Statt einer App
  # Sonderrechte zu geben, zähmen wir den Verursacher:
  #   - MemoryHigh: ab 10 GB wird der Build-cgroup aggressiv in den (neuen)
  #     Disk-Swap ausgelagert statt das ganze System zu ersticken (weiche
  #     Bremse, kein Kill).
  #   - OOMScoreAdjust: falls es DOCH global eng wird, ist der Build das
  #     bevorzugte Opfer — deine offene Arbeit (Affinity) überlebt.
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "10G";
    OOMScoreAdjust = 500;
  };

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
