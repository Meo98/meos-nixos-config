{
  pkgs,
  config,
  ...
}: {
  boot = {
    # MODIFIED 2026-06-28: linuxPackages_zen → linuxPackages_latest (zurück auf
    # upstream-zaneyos-Default). Zen war geerbtes Alt-Default und bricht in
    # nixos-unstable zeitweise (linux_zen baut kein bzImage → Rebuild-Fail nach
    # `fu`). Mainline-latest ist das immer-gebaute Kernel-Target und betrifft
    # beide Hosts. Gilt für meo + meo-work.
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = ["v4l2loopback"];
    extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
    kernel.sysctl = {"vm.max_map_count" = 2147483642;};
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Appimage Support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };
    plymouth.enable = true;
  };
}
