{
  pkgs,
  inputs,
  lib,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  noctaliaPkg = inputs.noctalia.packages.${system}.default;
  configDir = "${noctaliaPkg}/share/noctalia-shell";
  bt-audio-monitor = import ../../meo/scripts/bt-audio-monitor.nix {inherit pkgs;};
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

  # Bluetooth audio auto-switch: lauscht auf BT-Connect-Events und routet
  # Audio automatisch auf das verbindende Gerät um (wie macOS/Windows).
  systemd.user.services.bt-audio-monitor = {
    Unit = {
      Description = "Bluetooth audio auto-switch monitor";
      After = [ "graphical-session.target" "pipewire.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${bt-audio-monitor}/bin/bt-audio-monitor";
      Restart = "on-failure";
      RestartSec = "5s";
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

  # Seed the configuration when the noctalia package version changes.
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

  # Patch Noctalia's AudioService.qml so that clicking a device in the audio
  # panel ALSO updates WirePlumber's system-wide default sink (via wpctl),
  # not just Quickshell's internal preference. Without this, other apps
  # (Tidal, browsers, …) ignore Noctalia's selection. Idempotent — uses a
  # marker comment to detect prior patches and skip re-patching.
  home.activation.patchNoctaliaAudioService = lib.hm.dag.entryAfter ["seedNoctaliaShellCode"] ''
    set -eu
    QML="$HOME/.config/quickshell/noctalia-shell/Services/Media/AudioService.qml"
    MARKER="// PATCH: zaneyos wpctl set-default"

    if [ -f "$QML" ] && ! ${pkgs.gnugrep}/bin/grep -qF "$MARKER" "$QML"; then
      $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i \
        -e '/Pipewire\.preferredDefaultAudioSink = newSink;/a\    if (newSink) Quickshell.execDetached(["wpctl", "set-default", String(newSink.id)]); '"$MARKER" \
        -e '/Pipewire\.preferredDefaultAudioSource = newSource;/a\    if (newSource) Quickshell.execDetached(["wpctl", "set-default", String(newSource.id)]); '"$MARKER" \
        "$QML"
    fi
  '';

  # After every rebuild, reload systemd and restart noctalia so the running
  # quickshell binary always matches the IPC client. quickshell can update
  # independently of the noctalia package (separate flake input), so a
  # version-marker check alone is not enough.
  home.activation.restartNoctaliaService = lib.hm.dag.entryAfter ["patchNoctaliaAudioService"] ''
    $DRY_RUN_CMD sh -c "systemctl --user daemon-reload && systemctl --user restart noctalia-shell || true"
  '';
}
