{host, pkgs, ...}: let
  inherit (import ../../../hosts/${host}/variables.nix) printEnable;
in {
  services = {
    printing = {
      enable = printEnable;
      # MODIFIED: foomatic-db-engine entfernt (nur runtime-PPD-generation nötig, wir
      # nutzen statische PPDs aus foomatic-db-ppds). Spart ~30 MB im closure.
      drivers = [
        pkgs.cups-filters
        pkgs.foomatic-db-ppds-withNonfreeDb # liefert KONICA_MINOLTA-bizhub_C451 PPD
        pkgs.gutenprint                     # Konica Minolta + viele andere Treiber
      ];

      # MODIFIED: Print-to-PDF virtueller Drucker. Druckt nach
      # ~/Documents/Spool/<jobname>.pdf — nützlich für Proof-Prints von
      # Elektroplänen ohne realen Papierverbrauch.
      cups-pdf = {
        enable = printEnable;
        instances.pdf.installPrinter = true;
      };
    };

    avahi = {
      enable = printEnable;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = printEnable;

    # MODIFIED: Color management (ICC profiles) — relevant wenn farbgenaue Drucke
    # (Logos, Fotos) wichtig sind. Kostet ~5 MB, läuft als dbus-service nur bei
    # Bedarf. Konica Minolta C451 ist ein Color-Drucker, ICC-Profile machen Sinn.
    colord.enable = printEnable;
  };
}
