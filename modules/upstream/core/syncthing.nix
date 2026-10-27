{username, ...}: {
  services.syncthing = {
    enable = true; # MODIFIED: Chats/Ordner zwischen meo und meo-work abgleichen
    # MODIFIED: Ports 22000 (TCP/UDP) + 21027 (UDP, Discovery) öffnen, damit
    # sich die Hosts im selben Netz direkt finden statt über Relays
    openDefaultPorts = true;
    user = "${username}";
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
  };
}
