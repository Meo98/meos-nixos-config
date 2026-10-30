{ pkgs, ... }:
# PAT-Manager (Megger-PAT420-Backups) im App-Launcher.
#
# Das Programm wird nicht als Flake-Input eingebunden, sondern beim Start mit
# `nix run` direkt aus dem Projektordner gebaut: so ist immer der aktuelle
# Code aus dem Repo drin, und die CI braucht den Ordner nicht. Der erste Start
# nach einer Code-Änderung dauert darum etwa eine Minute (Build), danach ist
# er sofort da. Der Ordner liegt per Syncthing auf beiden Hosts gleich.
let
  projekt = "/home/meo/Dokumente/Technorama_Projekte/megger-tool";
  starter = pkgs.writeShellScriptBin "pat-manager-start" ''
    exec ${pkgs.nix}/bin/nix run "path:${projekt}" -- "$@"
  '';
in {
  home.packages = [ starter ];

  xdg.desktopEntries.pat-manager = {
    name = "PAT-Manager";
    comment = "Megger-PAT420-Backups ansehen, bearbeiten und als PDF ausgeben";
    icon = "${projekt}/packaging/pat-manager.svg";
    exec = "pat-manager-start %f";
    terminal = false;
    type = "Application";
    categories = [ "Office" "Utility" ];
    mimeType = [ "application/vnd.sqlite3" ];
  };
}
