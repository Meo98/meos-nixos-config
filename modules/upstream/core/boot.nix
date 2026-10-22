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
    # MODIFIED 2026-10-22: Ab Kernel 7.3 legt `make modules_install` von
    # v4l2loopback auch die depmod-Indizes (modules.alias.bin, modules.dep …)
    # in $out. Die kollidieren im buildEnv mit denen des Kernels
    # ("conflicting subpath ... modules.alias.bin") → System baut nicht.
    # Die Indizes erzeugt NixOS ohnehin selbst fuer den ganzen Baum, also hier
    # wegwerfen; nur das .ko bleibt. Entfernen, sobald nixpkgs das selbst fixt
    # (Test: `ls $(nix eval --raw …v4l2loopback.outPath)/lib/modules/*/`).
    extraModulePackages = [
      (config.boot.kernelPackages.v4l2loopback.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            find $out/lib/modules -maxdepth 2 -type f -name 'modules.*' -delete
          '';
      }))
    ];
    kernel.sysctl = {"vm.max_map_count" = 2147483642;};
    loader.systemd-boot.enable = true;
    # MODIFIED 2026-08-20: Boot-Einträge begrenzen, damit /boot (vfat) nicht
    # langfristig volläuft. 10 Generationen im Bootmenü reichen für Rollback.
    loader.systemd-boot.configurationLimit = 10;
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
