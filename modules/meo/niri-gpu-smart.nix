{pkgs, ...}:
# Dock-abhaengige GPU-Wahl fuer niri auf Host meo (Intel Arc iGPU + NVIDIA RTX 4080).
#
# Gleiche Ausgangslage wie bei modules/meo/hyprland-gpu-smart.nix: externe
# Monitore haengen an der NVIDIA-dGPU. Rendert der Compositor auf der iGPU, wird
# jeder Frame ueber PCIe kopiert -> Cursor-Lag. Im mobilen Betrieb soll die dGPU
# dagegen nach D3cold fallen duerfen.
#
# Unterschied zu Hyprland: niri kennt kein AQ_DRM_DEVICES. Die Renderer-Wahl
# sitzt in der Config unter debug { render-drm-device "..." }. Und weil niri
# KEIN include in KDL unterstuetzt (verifiziert: `niri validate` bricht mit
# Parse-Fehler), kann kein Fragment nachgeladen werden. Stattdessen: die
# HM-Config kopieren, den passenden debug-Block anhaengen und niri mit -c auf
# die Kopie zeigen lassen.
#
# WICHTIG: In modules/meo/niri/ darf deshalb KEIN debug-Block stehen, sonst
# entsteht er hier doppelt.
let
  nvidiaPci = "0000:01:00.0";
  intelPci = "0000:00:02.0";

  niriSmart = pkgs.writeShellApplication {
    name = "niri-smart";
    runtimeInputs = with pkgs; [coreutils findutils gnugrep niri];
    text = ''
      set -u

      resolve_render_node() {
        local pci="$1" node
        node=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'renderD*' -printf '%f\n' 2>/dev/null | head -n1) || true
        if [ -n "''${node:-}" ] && [ -e "/dev/dri/$node" ]; then
          printf '%s\n' "/dev/dri/$node"
        fi
      }

      resolve_card() {
        local pci="$1" card
        card=$(find "/sys/bus/pci/devices/$pci/drm" -maxdepth 1 -name 'card*' -printf '%f\n' 2>/dev/null | head -n1) || true
        printf '%s\n' "''${card:-}"
      }

      nvidia_node=$(resolve_render_node "${nvidiaPci}")
      intel_node=$(resolve_render_node "${intelPci}")
      nvidia_card=$(resolve_card "${nvidiaPci}")

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

      if [ "$external_connected" = "1" ] && [ -n "$nvidia_node" ]; then
        render_node="$nvidia_node"
        mode="docked: NVIDIA als Renderer"
      elif [ -n "$intel_node" ]; then
        render_node="$intel_node"
        mode="mobil: Intel, NVIDIA darf schlafen"
      else
        render_node=""
        mode="fallback: keine GPU-Bindung (Nodes nicht aufloesbar)"
      fi

      printf '[niri-smart] %s -- render-drm-device=%s\n' "$mode" "''${render_node:-unset}" >&2

      base="$HOME/.config/niri/config.kdl"
      generated="''${XDG_RUNTIME_DIR:-/tmp}/niri-config.kdl"

      # "niri --session" ohne -c sucht selbst unter genau diesem Pfad. Fehlt
      # die Datei, faengt niris eigener Default das ab. Existiert sie aber nur
      # mit falschen Rechten, laeuft niri hier in denselben Lesefehler --
      # dieser Fallback rettet also nur den "fehlt"-Fall, nicht den "kaputt"-Fall.
      if [ ! -r "$base" ]; then
        printf '[niri-smart] %s nicht lesbar, ueberlasse Config-Suche niri selbst\n' "$base" >&2
        exec niri --session "$@"
      fi

      if ! cp "$base" "$generated"; then
        printf '[niri-smart] Kopie von %s nach %s fehlgeschlagen, starte mit HM-Config\n' "$base" "$generated" >&2
        exec niri --session "$@"
      fi

      if [ -n "$render_node" ]; then
        {
          printf '\n// von niri-smart ergaenzt (%s)\n' "$mode"
          printf 'debug {\n    render-drm-device "%s"\n}\n' "$render_node"
        } >> "$generated"
      fi

      # Zusaetzlich zum Statuscode: "cp" haette (z.B. bei ENOSPC) auch mit
      # Fehler durchlaufen koennen, ohne dass wir es hier abgefangen haetten,
      # und dann haette ">>" oben die Datei aus dem Nichts angelegt -- so eine
      # Mini-Datei aus nur dem debug-Block besteht "niri validate" (sie ist
      # syntaktisch gueltiges KDL), waere aber eine Session ohne jegliche
      # Binds. Deshalb: die Kopie muss mindestens so gross sein wie die Basis.
      base_size=$(wc -c < "$base")
      generated_size=$(wc -c < "$generated")
      if [ "$generated_size" -lt "$base_size" ]; then
        printf '[niri-smart] generierte Config (%s Bytes) kleiner als Basis (%s Bytes), starte mit HM-Config\n' "$generated_size" "$base_size" >&2
        exec niri --session "$@"
      fi

      # Bricht lieber hier ab als in einer schwarzen Session.
      if ! niri validate --config "$generated"; then
        printf '[niri-smart] generierte Config ungueltig, starte mit HM-Config\n' >&2
        exec niri --session "$@"
      fi

      exec niri --session -c "$generated" "$@"
    '';
  };

  niriSmartSession =
    pkgs.runCommand "niri-smart-session" {
      passthru.providedSessions = ["niri-smart"];
    } ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/niri-smart.desktop <<'EOF'
      [Desktop Entry]
      Name=niri (Smart GPU)
      Comment=niri mit Auto-Erkennung der NVIDIA-GPU beim Docken
      Exec=niri-smart
      Type=Application
      EOF
    '';
in {
  environment.systemPackages = [niriSmart];
  services.displayManager.sessionPackages = [niriSmartSession];
}
