{ config, pkgs, inputs, lib, ... }: {
  imports = [
    ./hardware.nix
    ./host-packages.nix
    ./kanata.nix
    ./affinity.nix
  ];

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
  boot.kernelParams = [ "snd_hda_intel.power_save=0" "snd_hda_intel.power_save_controller=N" "i915.enable_dpcd_backlight=3" ];
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    # Deaktiviert den Standby-Modus in PipeWire
    extraConfig.pipewire."99-disable-suspend" = {
      "context.properties" = {
        "node.pause-on-idle" = false;
      };
    };
  };

  # --- WEITERE SERVICES ---
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  services.udev.extraRules = ''
    # Keychron Geräte (Vendor ID 3434)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
    # STM32 Bootloader
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", TAG+="uaccess"
    # Keychron Link Dongle
    SUBSYSTEM=="usb", ATTRS{idVendor}=="3434", TAG+="uaccess"
  '';

  # --- LOGIND: Lid-Close ignorieren, Suspend nur über hypridle ---
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
  };

  # --- TRAVEL-MODE: root-helper für CPU/GPU Power-Knobs ---
  environment.systemPackages = let
    travel-power = pkgs.writeShellScriptBin "travel-power" ''
      case "''${1:-}" in
        on)
          echo quiet > /sys/firmware/acpi/platform_profile 2>/dev/null || true
          for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
            echo 800000 > "$cpu" 2>/dev/null || true
          done
          echo auto > /sys/bus/pci/devices/0000:01:00.0/power/control 2>/dev/null || true
          ;;
        off)
          echo balanced > /sys/firmware/acpi/platform_profile 2>/dev/null || true
          for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
            echo 4800000 > "$cpu" 2>/dev/null || true
          done
          ;;
        *) echo "Usage: travel-power {on|off}" >&2; exit 2 ;;
      esac
    '';
  in [ travel-power ];

  security.sudo.extraRules = [{
    users = [ "meo" ];
    commands = [
      { command = "/run/current-system/sw/bin/travel-power"; options = [ "NOPASSWD" ]; }
    ];
  }];

  # --- BENUTZER & GRUPPEN ---
  users.users."meo".extraGroups = [ "dialout" "input" "uinput" ];

  # --- STANDARD ANWENDUNGEN ---
  xdg.mime.defaultApplications = {
    "text/html" = "vivaldi-stable.desktop";
    "x-scheme-handler/http" = "vivaldi-stable.desktop";
    "x-scheme-handler/https" = "vivaldi-stable.desktop";
    "x-scheme-handler/about" = "vivaldi-stable.desktop";
    "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
  };
}
