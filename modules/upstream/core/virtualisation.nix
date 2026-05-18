{pkgs, ...}: {
  # Only enable either docker or podman -- Not both
  virtualisation = {
    docker = {
      enable = true;
    };

    podman.enable = false;

    libvirtd = {
      enable = false;
    };

    virtualbox.host.enable = false;
  };

  programs = {
    virt-manager.enable = false;
  };

  # Explizit deaktivieren, damit der Service beim 'nixos-rebuild switch'
  # nicht hängt und den Bildschirm einfriert (bekannter NixOS-Bug).
  systemd.services.libvirt-guests.enable = false;

  environment.systemPackages = with pkgs; [
    virt-viewer # View Virtual Machines
    lazydocker
    docker-client
  ];
}
