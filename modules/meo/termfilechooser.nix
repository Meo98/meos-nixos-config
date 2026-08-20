{
  pkgs,
  lib,
  ...
}: let
  # Datei-Picker global durch yazi ersetzen (via xdg-desktop-portal-
  # termfilechooser). Betrifft alle Apps, die den Portal-FileChooser nutzen.
  # Portal-Backend + FileChooser-Impl werden in core/flatpak.nix gesetzt;
  # hier nur die User-Config (welcher Dateimanager + wie gestartet).
  tfc = pkgs.xdg-desktop-portal-termfilechooser;

  # Eigener Wrapper: hardcodet PATH (yazi+kitty), damit es auch im minimalen
  # Environment des dbus-aktivierten Portal-Dienstes funktioniert.
  yaziWrapper = pkgs.writeShellScript "termfilechooser-yazi" ''
    export PATH="${lib.makeBinPath [pkgs.yazi pkgs.kitty pkgs.coreutils]}:$PATH"
    export TERMCMD="kitty --title termfilechooser"
    exec ${tfc}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh "$@"
  '';
in {
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${yaziWrapper}
    default_dir=$HOME
  '';
}
