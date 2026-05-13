{ pkgs, ... }:

let
  travel-mode = pkgs.writeShellApplication {
    name = "travel-mode";
    runtimeInputs = with pkgs; [
      coreutils
      hyprland
    ];
    text = ''
      STATE_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/travel-mode-active"

      activate() {
        echo ">>> Travel-Mode: Aktiviere Stromsparmodus..."
        hyprctl dispatch dpms off 2>/dev/null || true
        sudo travel-power on
        touch "$STATE_FILE"
        echo ">>> Travel-Mode AKTIV"
        echo "    Display: aus | CPU: 800 MHz | GPU: auto-suspend"
        echo "    Deaktivieren: travel-mode off"
      }

      deactivate() {
        echo ">>> Travel-Mode: Deaktiviere..."
        hyprctl dispatch dpms on 2>/dev/null || true
        sudo travel-power off
        rm -f "$STATE_FILE"
        echo ">>> Travel-Mode AUS — volle Leistung"
      }

      status() {
        if [ -f "$STATE_FILE" ]; then echo "Travel-Mode: AKTIV"
        else echo "Travel-Mode: inaktiv"; fi
        echo ""
        echo "Profil:    $(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo '?')"
        echo "CPU max:   $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo '?') kHz"
        echo "CPU jetzt: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo '?') kHz"
        echo "GPU:       $(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo '?')"
        nvidia-smi --query-gpu=power.draw,temperature.gpu --format=csv,noheader 2>/dev/null || true
      }

      case "''${1:-}" in
        on|start)   activate ;;
        off|stop)   deactivate ;;
        status|"")  status ;;
        *)          echo "Usage: travel-mode {on|off|status}" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  home.packages = [ travel-mode ];
}
