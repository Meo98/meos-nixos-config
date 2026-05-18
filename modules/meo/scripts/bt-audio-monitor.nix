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
    # bt-audio-monitor — polls BlueZ every 2s for newly-connected audio
    # devices and triggers bt-audio-switch for each one. Polling chosen
    # over event-driven (bluetoothctl --monitor / dbus-monitor) because
    # it has no TTY/stdin dependencies and survives every edge case
    # cleanly under systemd.

    POLL_INTERVAL=2

    log() {
      logger -t bt-audio-monitor -p info "$*" 2>/dev/null || true
      echo "[bt-audio-monitor] $*" >&2
    }

    list_connected_audio_macs() {
      # Returns one MAC per line for all currently connected BT audio devices.
      local macs
      macs=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
      [ -z "$macs" ] && return 0

      while IFS= read -r mac; do
        [ -z "$mac" ] && continue
        local icon
        icon=$(bluetoothctl info "$mac" 2>/dev/null \
          | grep -oE 'Icon: [^[:space:]]+' \
          | awk '{print $2}')
        case "$icon" in
          audio-headphones|audio-headset|audio-speakers|audio-card|audio-input-microphone)
            echo "$mac"
            ;;
        esac
      done <<< "$macs"
    }

    log "Starting BT audio connection monitor (polling every ''${POLL_INTERVAL}s)"

    PREV=""
    while true; do
      CURRENT=$(list_connected_audio_macs | sort -u | tr '\n' ' ')

      # Detect newly-connected MACs (present in CURRENT, not in PREV)
      for mac in $CURRENT; do
        if ! printf ' %s ' "$PREV" | grep -qF " $mac "; then
          log "Audio device $mac connected — invoking bt-audio-switch"
          bt-audio-switch "$mac" || log "switch failed for $mac"
        fi
      done

      PREV="$CURRENT"
      sleep "$POLL_INTERVAL"
    done
  '';
}
