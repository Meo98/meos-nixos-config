{
  pkgs,
  host,
  options,
  ...
}: let
  inherit (import ../../../hosts/${host}/variables.nix) hostId;
in {
  networking = {
    hostName = "${host}";
    hostId = hostId;
    networkmanager.enable = true;
    timeServers = options.networking.timeServers.default ++ ["pool.ntp.org"];
    firewall = {
      enable = true;
      # MODIFIED 2026-08-20: manuelle KDE-Connect-Ports (59010/59011) entfernt.
      # Das waren falsche Ports (KDE Connect nutzt 1714–1764) und obendrein
      # totes Cruft: auf meo ist `programs.kdeconnect.enable = true` gesetzt,
      # dessen NixOS-Modul die korrekten Ports selbst oeffnet. meo-work nutzt
      # KDE Connect nicht → braucht die Ports gar nicht.
      # MODIFIED 2026-10-27: Port 22 nicht mehr global offen. SSH nur noch
      # übers Tailscale-Netz (modules/meo/tailscale.nix, tailscale0).
      allowedTCPPorts = [ ];
    };
  };

  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
