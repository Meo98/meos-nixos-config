{ pkgs, ... }:

let
  bright-smart = pkgs.writeShellApplication {
    name = "bright-smart";
    runtimeInputs = with pkgs; [
      ddcutil
      brightnessctl
      coreutils
      gawk
      ripgrep
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      cmd="''${1:-}"
      ddc_step="''${2:-10}"                  # 0..100 (Monitor)
      int_step="''${3:-5%}"                  # Laptop backlight
      target_connector="''${4:-card0-HDMI-A-1}"

      # Speed knobs:
      # 0.2 ist oft schnell & stabil, wenn dein Monitor zickt: 0.3 / 0.5 / 1.0
      sleep_mul="''${5:-0.2}"

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/bright-smart"
      cache_file="$state_dir/bus"
      mkdir -p "$state_dir"

      conn_status_path="/sys/class/drm/$target_connector/status"

      is_connected() {
        [ -r "$conn_status_path" ] && rg -qi "^connected$" "$conn_status_path"
      }

      find_bus_by_connector() {
        # einmalig bus finden, wenn cache fehlt
        ddcutil detect 2>/dev/null | awk -v want="$target_connector" '
          function grab_bus(line,  m) {
            if (match(line, /\/dev\/i2c-([0-9]+)/, m)) return m[1];
            return "";
          }
          $1=="Display" { bus=""; conn=""; }
          $1=="I2C" && $2=="bus:" { bus=grab_bus($0); }
          $1=="DRM_connector:" { conn=$2; }
          bus!="" && conn==want { print bus; exit 0; }
        '
      }

      get_bus() {
        # Cache bevorzugen (kein getvcp, kein detect)
        if [ -f "$cache_file" ]; then
          b="$(cat "$cache_file" 2>/dev/null || true)"
          if [[ "''${b:-}" =~ ^[0-9]+$ ]]; then
            echo "$b"; return 0
          fi
        fi

        b="$(find_bus_by_connector || true)"
        if [[ "''${b:-}" =~ ^[0-9]+$ ]]; then
          echo "$b" > "$cache_file"
          echo "$b"; return 0
        fi

        return 1
      }

      ext_set() {
        local bus="$1"
        local delta="$2"
        # --bus beschleunigt, weil er nicht jedes Mal alle i2c-Busse scannt :contentReference[oaicite:2]{index=2}
        # --sleep-multiplier reduziert die DDC/CI waits => viel schneller (aber ggf. zu aggressiv) :contentReference[oaicite:3]{index=3}
        ddcutil --bus "$bus" --sleep-multiplier "$sleep_mul" --noverify setvcp 10 "$delta" -q
      }

      laptop_set() {
        local delta="$1"
        for dev in intel_backlight nvidia_0; do
          if [ -d "/sys/class/backlight/$dev" ]; then
            brightnessctl -d "$dev" set "$delta" && return 0
          fi
        done
        return 1
      }

      case "$cmd" in
        up)
          if is_connected && bus="$(get_bus)"; then
            ext_set "$bus" "+$ddc_step" || laptop_set "+$int_step" || true
          else
            laptop_set "+$int_step" || true
          fi
          ;;
        down)
          if is_connected && bus="$(get_bus)"; then
            ext_set "$bus" "-$ddc_step" || laptop_set "$int_step-" || true
          else
            laptop_set "$int_step-" || true
          fi
          ;;
        *)
          echo "Usage: bright-smart {up|down} [ddc_step] [int_step] [drm_connector] [sleep_multiplier]" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [ bright-smart ];
}
