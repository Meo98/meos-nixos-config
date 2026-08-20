{pkgs, ...}: {
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      # MODIFIED 2026-08-20: yazi-Datei-Picker (termfilechooser). User-Config
      # (welcher Dateimanager) in modules/meo/termfilechooser.nix.
      pkgs.xdg-desktop-portal-termfilechooser
    ];
    configPackages = [pkgs.hyprland];
    # MODIFIED 2026-08-20: Datei-Picker global auf termfilechooser umbiegen
    # (oeffnet yazi im Terminal statt des grafischen Dialogs).
    config.common."org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
  };
  services = {
    flatpak = {
      enable = true;

      # List the Flatpak applications you want to install
      # Use the official Flatpak application ID (e.g., from flathub.org)
      # Examples:
      packages = [
        #"com.github.tchx84.Flatseal" #Manage flatpak permissions - should always have this
        #"com.rtosta.zapzap"              # WhatsApp client
        #"io.github.flattool.Warehouse"   # Manage flatpaks, clean data, remove flatpaks and deps
        #"it.mijorus.gearlever"           # Manage and support AppImages
        #"io.github.freedoom.Phase1"      #  Classic Doom FPS 1
        #"io.github.freedoom.Phase2"      #  Classic Doom FPS 2
        #"io.github.dvlv.boxbuddyrs"      #  Manage distroboxes
        #"de.schmidhuberj.tubefeeder"     #watch YT videos

        # Add other Flatpak IDs here, e.g., "org.mozilla.firefox"
      ];

      # Optional: Automatically update Flatpaks when you run nixos-rebuild swit ch
      update.onActivation = true;
    };
  };
}
