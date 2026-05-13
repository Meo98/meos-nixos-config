{profile, ...}: {
  # Services to start
  services = {
    upower.enable = true; # noctalia shell battery
    libinput.enable = true; # Input Handling
    fstrim.enable = true; # SSD Optimizer
    gvfs.enable = true; # For Mounting USB & More
    power-profiles-daemon.enable = true;
    openssh = {
      enable = true; # Enable SSH
      settings = {
        PermitRootLogin = "no"; # Prevent root from SSH login
        PasswordAuthentication = false; # Key-only — add pubkey to ~/.ssh/authorized_keys first!
        KbdInteractiveAuthentication = false;
      };
      ports = [22];
    };
    blueman.enable = true; # Bluetooth Support
    tumbler.enable = true; # Image/video preview
    gnome.gnome-keyring.enable = true;

    smartd = {
      enable =
        if profile == "vm"
        then false
        else true;
      autodetect = true;
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      extraConfig.pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 256;
          "resample.quality" = 10;
        };
      };
      # RNNoise filter-chain hier entfernt — PipeWire 1.6.3 hat Probleme mit dem
      # absoluten Plugin-Pfad. Stattdessen: EasyEffects-GUI verwenden, dort gibt's
      # "Speech Enhancement (RNNoise)" als klickbaren Effekt.
      extraConfig.pipewire-pulse."92-low-latency" = {
        context.modules = [
          {
            name = "libpipewire-module-protocol-pulse";
            args = {
              pulse.min.req = "256/48000";
              pulse.default.req = "256/48000";
              pulse.max.req = "256/48000";
              pulse.min.quantum = "256/48000";
              pulse.max.quantum = "256/48000";
            };
          }
        ];
      };
      # --- BLUETOOTH AUTO-SWITCH ---
      # Bluetooth-Geräte bekommen höchste Priorität, damit sie beim Verbinden
      # automatisch zum Default-Audio werden (wie macOS/Windows).
      wireplumber.extraConfig."51-bluez-autoswitch" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.roles" = [
            "a2dp_sink"
            "a2dp_source"
            "bap_sink"
            "bap_source"
            "hfp_hf"
            "hfp_ag"
          ];
        };
        "monitor.bluez.rules" = [
          {
            matches = [
              { "device.name" = "~bluez_card.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2000;
                "priority.session" = 2000;
              };
            };
          }
          {
            matches = [
              { "node.name" = "~bluez_output.*"; }
              { "node.name" = "~bluez_input.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2000;
                "priority.session" = 2000;
              };
            };
          }
        ];
      };
    };
  };
}
