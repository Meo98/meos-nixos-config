{
  config,
  pkgs,
  ...
}: {
  xdg.portal = {
    enable = true;
    # MODIFIED 2026-10-26: dasselbe Portal wie programs.hyprland verwenden.
    # Seit nixpkgs 3ec6363 baut programs.hyprland ein eigenes Portal-Derivat;
    # zusammen mit pkgs.xdg-desktop-portal-hyprland kollidierte
    # xdg-desktop-portal-hyprland.service in user-units ("File exists").
    extraPortals = [config.programs.hyprland.portalPackage];
    configPackages = [pkgs.hyprland];
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
