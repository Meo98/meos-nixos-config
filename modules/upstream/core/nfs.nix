{
  host,
  lib,
  ...
}: let
  inherit (import ../../../hosts/${host}/variables.nix) enableNFS;
in {
  # NFS client support only — kein Server-Daemon, keine offenen Ports
  boot.supportedFilesystems = lib.optional enableNFS "nfs";
  services.rpcbind.enable = enableNFS;
}
