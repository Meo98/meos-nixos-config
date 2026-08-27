{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "travel-mode";
  runtimeInputs = with pkgs; [
    coreutils
    hyprland
  ];
  text = ''
    STATE_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/travel-mode-active"

    # MODIFIED 2026-08-27 (niri-Migration): DPMS je nach laufender Session.
    # Vorher hart `hyprctl dispatch dpms`, was unter niri wirkungslos war —
    # der Bildschirm waere im Travel-Mode angeblieben.
    #
    # MODIFIED 2026-08-27 (Fix Runde 1): niri bewusst NICHT in runtimeInputs —
    # dieses Script haengt via modules/meo/scripts.nix -> modules/meo/default.nix
    # auch an meo-work, das niemals niri hat. runtimeInputs wird PATH nur
    # vorangestellt, nicht ersetzt: im niri-Zweig reicht das ambiente PATH,
    # dort ist niri per niri-Modul (home.packages) ohnehin vorhanden, sobald
    # NIRI_SOCKET gesetzt ist. Fehlt niri trotzdem im PATH, sichtbarer Hinweis
    # auf stderr statt stillem No-op.
    dpms() {
      if [ -n "''${NIRI_SOCKET:-}" ]; then
        if command -v niri >/dev/null 2>&1; then
          niri msg action "power-$1-monitors" 2>/dev/null || true
        else
          echo "travel-mode: niri-Session erkannt, aber 'niri' nicht im PATH — Bildschirm bleibt an" >&2
        fi
      else
        hyprctl dispatch dpms "$1" 2>/dev/null || true
      fi
    }

    activate() {
      echo ">>> Travel-Mode: Aktiviere Stromsparmodus..."
      dpms off
      sudo travel-power on
      touch "$STATE_FILE"
      echo ">>> Travel-Mode AKTIV"
      echo "    Display: aus | CPU: 800 MHz | GPU: auto-suspend"
      echo "    Deaktivieren: travel-mode off"
    }

    deactivate() {
      echo ">>> Travel-Mode: Deaktiviere..."
      dpms on
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
}
