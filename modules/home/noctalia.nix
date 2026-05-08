{
  pkgs,
  inputs,
  lib,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  noctaliaPkg = inputs.noctalia.packages.${system}.default;
  configDir = "${noctaliaPkg}/share/noctalia-shell";
in {
  # Install the Noctalia package
  home.packages = [
    noctaliaPkg
    pkgs.quickshell # Ensure quickshell is available for the service
  ];

  # Monitor Hot-Plug: Layout wiederherstellen wenn Bildschirm angeschlossen wird
  home.file.".local/bin/hypr-monitor-hotplug" = {
    executable = true;
    text = ''
      #!/bin/sh
      export PATH=/run/current-system/sw/bin:/etc/profiles/per-user/meo/bin:$PATH
      SOCK=$(ls /run/user/1000/hypr/ 2>/dev/null | head -1)
      socat - UNIX-CONNECT:/run/user/1000/hypr/$SOCK/.socket2.sock | \
        while read -r line; do
          case "$line" in
            monitoradded*)
              sleep 2
              hyprctl dispatch dpms on
              hyprctl reload
              ;;
          esac
        done
    '';
  };

  systemd.user.services.hyprland-monitor-hotplug = {
    Unit = {
      Description = "Restore Hyprland monitor layout on hotplug";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "%h/.local/bin/hypr-monitor-hotplug";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Systemd user service — startet noctalia automatisch und nach jedem rebuild neu
  systemd.user.services.noctalia-shell = {
    Unit = {
      Description = "Noctalia Shell Bar";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "/bin/sh -c 'pkill -f \"quickshell$\" || true'";
      ExecStart = "${noctaliaPkg}/bin/noctalia-shell";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Seed the configuration — update automatically when the noctalia package version changes
  home.activation.seedNoctaliaShellCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -eu
    DEST="$HOME/.config/quickshell/noctalia-shell"
    SRC="${configDir}"
    VERSION_MARKER="$DEST/.noctalia-nix-version"
    CURRENT_VERSION="${noctaliaPkg}"

    if [ ! -d "$DEST" ] || [ ! -f "$VERSION_MARKER" ] || [ "$(cat "$VERSION_MARKER" 2>/dev/null)" != "$CURRENT_VERSION" ]; then
      $DRY_RUN_CMD rm -rf "$DEST"
      $DRY_RUN_CMD mkdir -p "$HOME/.config/quickshell"
      $DRY_RUN_CMD cp -R "$SRC" "$DEST"
      $DRY_RUN_CMD chmod -R u+rwX "$DEST"
      $DRY_RUN_CMD sh -c "echo '$CURRENT_VERSION' > '$VERSION_MARKER'"
    fi
  '';
}
