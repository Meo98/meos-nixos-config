{username, ...}: {
  services.syncthing = {
    enable = true; # MODIFIED: Chats/Ordner zwischen meo und meo-work abgleichen
    # MODIFIED: Ports NICHT global öffnen; Syncthing läuft übers Tailscale-Netz,
    # Port 22000 ist nur auf tailscale0 offen (modules/meo/tailscale.nix)
    openDefaultPorts = false;
    user = "${username}";
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
  };
}
