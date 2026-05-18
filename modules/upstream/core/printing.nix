{host, pkgs, ...}: let
  inherit (import ../../../hosts/${host}/variables.nix) printEnable;
in {
  services = {
    printing = {
      enable = printEnable;
      drivers = [
        pkgs.cups-filters
        pkgs.foomatic-db-ppds-withNonfreeDb
        pkgs.foomatic-db-engine
        pkgs.gutenprint # Konica Minolta Unterstützung
      ];
    };
    avahi = {
      enable = printEnable;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = printEnable;
  };
}
