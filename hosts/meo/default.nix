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
  boot.kernelParams = [ "snd_hda_intel.power_save=0" "snd_hda_intel.power_save_controller=N" ];
  
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
