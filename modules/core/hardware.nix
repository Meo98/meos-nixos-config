{pkgs, ...}: {
  hardware = {
    sane = {
      enable = true;
      extraBackends = [pkgs.sane-airscan];
      disabledDefaultBackends = ["escl"];
    };
    logitech.wireless.enable = false;
    logitech.wireless.enableGraphical = false;
    graphics.enable = true;
    enableRedistributableFirmware = true;
    keyboard.qmk.enable = true;

    # --- HIER IST DIE ÄNDERUNG ---
    # Wir machen aus "bluetooth.enable" einen Block "bluetooth = { ... }"
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          # Spoofing als Apple-Gerät (004C), damit LibrePods Features freischaltet
          DeviceID = "bluetooth:004C:0000:0000";

          # Zeigt Akku-Prozentwerte in Widgets/Waybar an
          Experimental = true;
          # Aktiviert Kernel-Experimental-Features (LE Audio, BAP)
          KernelExperimental = true;

          # Schnelleres Reconnect bei bekannten Geräten
          FastConnectable = true;
          # AirPods invalidieren manchmal den Pairing-Key nach BlueZ-Updates
          # → automatisches Re-Pairing ohne Bestätigungs-Dialog
          JustWorksRepairing = "always";
          # BR/EDR + LE parallel (für moderne Geräte nötig)
          ControllerMode = "dual";
        };
      };
    };
    # -----------------------------
  };
  local.hardware-clock.enable = false;
}
