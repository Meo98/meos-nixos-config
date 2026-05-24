{ pkgs, lib, ... }:

# Dock-aware Hyprland launcher for the meo host (Intel Arc iGPU + NVIDIA RTX 4080).
#
# Problem: external monitors on hybrid laptops are wired to the NVIDIA dGPU.
# When Hyprland renders on the Intel iGPU (the default), every frame for the
# external display gets copied across PCIe -> cursor lag, jittery scrolling.
#
# Fix: at session start, detect whether any non-eDP output on the NVIDIA card
# is connected. If yes, make NVIDIA the primary renderer via AQ_DRM_DEVICES.
# If no, pin Aquamarine to the Intel card only so NVIDIA can drop to D3cold
# (~0W) for battery savings on the go.
#
# Resolves card numbers from PCI addresses at launch time, so kernel-update
# induced card0/card1 reordering does not break the logic.

let
  nvidiaPci = "0000:01:00.0";
  intelPci  = "0000:00:02.0";

  hyprlandSmart = pkgs.writeShellApplication {
    name = "hyprland-smart";
    runtimeInputs = with pkgs; [ coreutils gnugrep ];
    text = ''
      set -u

      resolve_card() {
        local pci="$1" link card
        link=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'card*' -printf '%f\n' 2>/dev/null | head -n1) || true
        card="''${link:-}"
        if [ -n "$card" ] && [ -e "/dev/dri/$card" ]; then
          printf '%s\n' "$card"
        fi
      }

      nvidia_card=$(resolve_card "${nvidiaPci}")
      intel_card=$(resolve_card "${intelPci}")

      external_connected=0
      if [ -n "$nvidia_card" ]; then
        for status in /sys/class/drm/"$nvidia_card"-*/status; do
          [ -e "$status" ] || continue
          name=$(basename "$(dirname "$status")")
          case "$name" in
            *eDP*) continue ;;
          esac
          if [ "$(cat "$status")" = "connected" ]; then
            external_connected=1
            break
          fi
        done
      fi

      if [ "$external_connected" = "1" ] && [ -n "$nvidia_card" ] && [ -n "$intel_card" ]; then
        export AQ_DRM_DEVICES="/dev/dri/$nvidia_card:/dev/dri/$intel_card"
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export LIBVA_DRIVER_NAME=nvidia
        export GBM_BACKEND=nvidia-drm
        export __NV_PRIME_RENDER_OFFLOAD=1
        mode="docked: NVIDIA primary renderer"
      elif [ -n "$intel_card" ]; then
        export AQ_DRM_DEVICES="/dev/dri/$intel_card"
        mode="mobile: Intel only, NVIDIA free to suspend"
      else
        mode="fallback: no GPU pinning (cards not resolved)"
      fi

      printf '[hyprland-smart] %s -- AQ_DRM_DEVICES=%s\n' "$mode" "''${AQ_DRM_DEVICES:-unset}" >&2

      exec Hyprland "$@"
    '';
  };

  hyprlandSmartSession = pkgs.runCommand "hyprland-smart-session" {
    passthru.providedSessions = [ "hyprland-smart" ];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/hyprland-smart.desktop <<'EOF'
    [Desktop Entry]
    Name=Hyprland (Smart GPU)
    Comment=Hyprland with auto-detect of NVIDIA primary when docked
    Exec=hyprland-smart
    Type=Application
    EOF
  '';
in {
  environment.systemPackages = [ hyprlandSmart ];

  services.displayManager.sessionPackages = [ hyprlandSmartSession ];
}
