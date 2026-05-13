{pkgs, ...}: let
  bt-audio-switch = import ./bt-audio-switch.nix {inherit pkgs;};
in
pkgs.writeShellApplication {
  name = "bt-audio-monitor";
  runtimeInputs = with pkgs; [
    bt-audio-switch
    bluez
    coreutils
    gawk
    gnugrep
    gnused
    util-linux
  ];
  text = ''
    # bt-audio-monitor — long-running daemon that watches BlueZ for
    # connection events and triggers bt-audio-switch on any newly
    # connected BT audio device.

    log() {
      logger -t bt-audio-monitor -p info "$*" 2>/dev/null || true
      echo "[bt-audio-monitor] $*" >&2
    }

    is_audio_device() {
      # Inspect device info; match on Icon (most reliable BlueZ signal).
      local mac="$1"
      local icon
      icon=$(bluetoothctl info "$mac" 2>/dev/null \
        | grep -oE 'Icon: [^[:space:]]+' \
        | awk '{print $2}')
      case "$icon" in
        audio-headphones|audio-headset|audio-speakers|audio-card|audio-input-microphone)
          return 0 ;;
        *)
          return 1 ;;
      esac
    }

    log "Starting BT audio connection monitor"

    # `bluetoothctl --monitor` streams human-readable change events.
    # NO_COLOR=1 strips ANSI escapes; sed -u keeps it line-buffered.
    NO_COLOR=1 bluetoothctl --monitor 2>&1 \
      | sed -u 's/\x1b\[[0-9;]*m//g' \
      | grep --line-buffered -E '^\[CHG\] Device [0-9A-F:]{17} Connected: yes' \
      | while read -r line; do
          mac=$(echo "$line" | awk '{print $3}')
          [ -z "$mac" ] && continue

          # Small delay so BlueZ finishes setting up the device profile.
          sleep 1

          if is_audio_device "$mac"; then
            log "Audio device $mac connected — invoking bt-audio-switch"
            bt-audio-switch "$mac" || log "switch failed for $mac"
          else
            log "Ignoring non-audio device $mac"
          fi
        done
  '';
}
