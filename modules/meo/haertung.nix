# Härtung nach der Sicherheitsprüfung vom 17.11.2026 (beide Hosts).
{ pkgs, ... }: {
  # KDE Connect: nur noch übers Tailscale-Netz erreichbar, nicht mehr im
  # WLAN/LAN (Firmennetz!). Bewusst NICHT `programs.kdeconnect.enable`:
  # dessen NixOS-Modul öffnet 1714–1764 auf allen Schnittstellen. Darum hier
  # nur das Paket (bringt den Autostart des Daemons mit) und die Ports
  # einzeln auf tailscale0, wie SSH/Syncthing in tailscale.nix.
  #
  # Folge: Die automatische Suche (Broadcast im WLAN) geht nicht mehr. Am
  # Handy muss Tailscale an sein und der Laptop einmal unter
  # «Geräte per IP hinzufügen» mit seinem Tailscale-Namen eingetragen werden.
  environment.systemPackages = [ pkgs.kdePackages.kdeconnect-kde ];
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
  };

  # Firmware-Updates (BIOS, SSD, Logitech-Empfänger) über LVFS.
  # Prüfen: `fwupdmgr get-updates`, einspielen: `fwupdmgr update`.
  services.fwupd.enable = true;
}
