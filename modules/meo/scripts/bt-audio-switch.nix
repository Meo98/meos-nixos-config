{pkgs, ...}:
pkgs.writeShellApplication {
  name = "bt-audio-switch";
  runtimeInputs = with pkgs; [
    wireplumber
    pipewire
    bluez
    gawk
    gnugrep
    gnused
    coreutils
    util-linux
    jq
  ];
  text = ''
    # bt-audio-switch [MAC]
    # Switches system audio to a connected Bluetooth audio device.
    # With no argument: picks the first connected BT audio device.
    # With MAC argument (XX:XX:XX:XX:XX:XX): targets that specific device.

    log() {
      logger -t bt-audio-switch -p info "$*" 2>/dev/null || true
      echo "[bt-audio-switch] $*" >&2
    }

    # Find the bluez_card device ID from wpctl status.
    # If TARGET_MAC is set, only returns the matching card; otherwise the first.
    find_bluez_card() {
      local target_us="''${1:-}"
      [ -n "$target_us" ] && target_us="''${target_us//:/_}"

      # Get all device IDs in the Audio section that are bluez5
      local ids
      ids=$(wpctl status \
        | awk '/^Audio$/,/^Video$/' \
        | grep -E '\[bluez5\]' \
        | grep -oE '[0-9]+\.' \
        | tr -d '.')

      for id in $ids; do
        if [ -n "$target_us" ]; then
          if wpctl inspect "$id" 2>/dev/null | grep -qF "$target_us"; then
            echo "$id"
            return 0
          fi
        else
          echo "$id"
          return 0
        fi
      done
      return 1
    }

    # Read the MAC (underscored) from a bluez_card's device.name property.
    card_mac_underscored() {
      wpctl inspect "$1" 2>/dev/null \
        | awk -F'"' '/device\.name/ { sub(/^bluez_card\./, "", $2); print $2; exit }'
    }

    # Find best A2DP profile index for a card (prefer highest priority,
    # which is typically AAC for AirPods, SBC-XQ otherwise).
    find_a2dp_profile_index() {
      local card_id="$1"
      pw-cli enum-params "$card_id" EnumProfile 2>/dev/null \
        | awk '
          BEGIN { in_obj = 0; idx = ""; name = ""; prio = "" }
          /^[[:space:]]*Object:.*Profile/ {
            if (in_obj && name ~ /^a2dp-sink/) print prio "\t" idx
            in_obj = 1; idx = ""; name = ""; prio = ""
            next
          }
          in_obj && /Profile:index/ {
            getline; sub(/^[[:space:]]+Int[[:space:]]+/, ""); idx = $0; next
          }
          in_obj && /Profile:name/ {
            getline; sub(/^[[:space:]]+String[[:space:]]+"/, ""); sub(/"$/, ""); name = $0; next
          }
          in_obj && /Profile:priority/ {
            getline; sub(/^[[:space:]]+Int[[:space:]]+/, ""); prio = $0; next
          }
          END {
            if (in_obj && name ~ /^a2dp-sink/) print prio "\t" idx
          }
        ' \
        | sort -rn | head -1 | awk '{print $2}'
    }

    # Find the bluez_output sink ID for given MAC (underscored).
    find_bluez_sink() {
      local mac_us="$1"
      local ids
      ids=$(wpctl status \
        | awk '/^Audio$/,/^Video$/' \
        | awk '/Sinks:/{p=1; next} /Sources:|Filters:|Streams:/{p=0} p' \
        | grep -oE '[0-9]+\.' \
        | tr -d '.')

      for id in $ids; do
        local name
        name=$(wpctl inspect "$id" 2>/dev/null | awk -F'"' '/node\.name/ { print $2; exit }')
        case "$name" in
          "bluez_output.''${mac_us}"*) echo "$id"; return 0 ;;
        esac
      done
      return 1
    }

    sink_node_name() {
      wpctl inspect "$1" 2>/dev/null \
        | awk -F'"' '/node\.name/ { print $2; exit }'
    }

    # Move all running playback streams to the given sink name.
    move_streams_to_sink() {
      local sink_name="$1"
      local stream_ids
      stream_ids=$(pw-dump 2>/dev/null \
        | jq -r '.[] | select(.info?.props?["media.class"] == "Stream/Output/Audio") | .id' \
        || true)

      [ -z "$stream_ids" ] && return 0

      local count=0
      while IFS= read -r sid; do
        [ -z "$sid" ] && continue
        if pw-metadata "$sid" target.object "$sink_name" >/dev/null 2>&1; then
          count=$((count + 1))
        fi
      done <<< "$stream_ids"

      log "Migrated $count active stream(s) to $sink_name"
    }

    main() {
      local target_mac="''${1:-}"
      local card_id=""

      # Wait up to 5s for the card to be visible to PipeWire.
      for _ in 1 2 3 4 5; do
        card_id=$(find_bluez_card "$target_mac" 2>/dev/null || true)
        [ -n "$card_id" ] && break
        sleep 1
      done

      if [ -z "$card_id" ]; then
        log "No connected Bluetooth audio card found ''${target_mac:+for MAC $target_mac}"
        return 1
      fi

      local mac_us
      mac_us=$(card_mac_underscored "$card_id")
      log "Found bluez card id=$card_id mac=$mac_us"

      local profile_idx
      profile_idx=$(find_a2dp_profile_index "$card_id")
      if [ -z "$profile_idx" ]; then
        log "No A2DP profile available on card $card_id — leaving as is"
        return 1
      fi

      log "Activating A2DP profile (index $profile_idx)"
      wpctl set-profile "$card_id" "$profile_idx" || true

      # Wait for the sink node to appear.
      local sink_id=""
      for _ in 1 2 3 4 5; do
        sink_id=$(find_bluez_sink "$mac_us" 2>/dev/null || true)
        [ -n "$sink_id" ] && break
        sleep 1
      done

      if [ -z "$sink_id" ]; then
        log "Bluetooth sink did not appear after profile switch"
        return 1
      fi

      local sink_name
      sink_name=$(sink_node_name "$sink_id")
      log "Setting default sink to id=$sink_id name=$sink_name"

      wpctl set-default "$sink_id"
      wpctl set-mute "$sink_id" 0 >/dev/null 2>&1 || true
      wpctl set-volume "$sink_id" 0.5 >/dev/null 2>&1 || true

      move_streams_to_sink "$sink_name"

      log "Done — audio routed to $sink_name"
    }

    main "$@"
  '';
}
