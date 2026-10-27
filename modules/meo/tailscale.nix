# Tailscale: privates WireGuard-Netz zwischen meo und meo-work (2026-10-27).
# Die Hosts erreichen sich darüber unter ihrem Namen (MagicDNS), auch durch
# NAT/Firmennetz. Einmalig pro Host anmelden: `sudo tailscale up`.
#
# SSH und Syncthing sind NUR noch über tailscale0 erreichbar, nicht mehr im
# normalen WLAN/LAN. Rückweg bei Problemen: physisch am Laptop sitzen und
# hier wieder öffnen.
{ ... }: {
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP 41641 für direkte Verbindungen statt DERP-Relay
  };

  # Port 22 nicht mehr global öffnen (Default wäre true)
  services.openssh.openFirewall = false;

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 22 22000 ]; # SSH, Syncthing
    allowedUDPPorts = [ 22000 ]; # Syncthing (QUIC)
  };
}
