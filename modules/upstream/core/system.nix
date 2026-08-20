{host, pkgs, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
  consoleKeyMap = vars.consoleKeyMap or "us";
in {
  nix = {
    # MODIFIED 2026-08-20: nix.gc deaktiviert. GC macht jetzt allein
    # programs.nh.clean (core/nh.nix, generationsbewusst: --keep 5
    # --keep-since 7d). Vorher liefen ZWEI GC-Timer mit widersprüchlicher
    # Retention (14d zeitbasiert vs. keep-5 zählbasiert). auto-optimise-store
    # (unten) bleibt aktiv — orthogonal zum GC.
    gc.automatic = false;
    settings = {
      download-buffer-size = 200000000;
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };
  };
  # MODIFIED 2026-08-20: flake-basiertes command-not-found funktioniert ohne
  # Nix-Channel nicht; stattdessen uebernimmt nix-index (modules/meo/dev-tools.nix)
  # die "command not found"-Vorschlaege. Deaktivieren, damit sich beide nicht
  # in die Quere kommen.
  programs.command-not-found.enable = false;

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "de_CH.UTF-8";
  };
  environment.variables = {
    NIXOS_OZONE_WL = "1";
    ZANEYOS_VERSION = "2.6.0";
    ZANEYOS = "true";
  };

  # --- External monitor brightness via DDC/CI (HDMI/DP) ---
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    ddcutil
  ];

  users.users.meo.extraGroups = [ "i2c" ];

  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';
  console.keyMap = "${consoleKeyMap}";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  system.stateVersion = "23.11"; # Do not change!
}
