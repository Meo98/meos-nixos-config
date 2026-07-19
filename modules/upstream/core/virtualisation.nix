{pkgs, ...}: {
  # Only enable either docker or podman -- Not both
  virtualisation = {
    docker = {
      enable = true;
      # MODIFIED 2026-07-19: live-restore (NixOS-Default true) laesst Container
      # beim docker.service-Stop absichtlich weiterlaufen. Folge bei jedem
      # Shutdown/Reboot: alle containerd-shims bleiben uebrig ("Unit process
      # ... remains running after unit stopped"), systemd-shutdown wartet
      # ~90s (DefaultTimeoutStopSec) auf SIGTERM-ignorierende Container-PID-1s
      # und killt dann hart -> Reboot haengt konstant ~2min UND die DBs
      # (CouchDB/Postgres/Synapse) werden jedes Mal unsauber abgeschossen.
      # liveRestore=false: dockerd stoppt beim Daemon-Stop alle Container
      # sauber. Trade-off: ein docker.service-Restart (z.B. seltener
      # nixos-switch-Fall) stoppt die Container mit; restart-policy
      # unless-stopped bringt sie danach wieder hoch.
      liveRestore = false;
      # Obergrenze fuers Container-Stoppen beim Daemon-Shutdown (Default 15s).
      # Wichtig: nextcloud-aio-database hat StopTimeout=1800 -- das darf den
      # Reboot nicht blockieren; docker.service selbst hat TimeoutStop=90s.
      daemon.settings."shutdown-timeout" = 20;
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
