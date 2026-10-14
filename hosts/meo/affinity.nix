{ pkgs, inputs, username, lib, host, ci ? false, ... }:

let
  # Resolve variables.nix relative to the actual host being built. The `host`
  # specialArg is set in flake.nix per host (e.g. "meo" or "meo-work"), so
  # importing affinity.nix from a different host directory still picks up the
  # right variables.nix.
  hostVars = import (../. + "/${host}/variables.nix");
  # `ci` (specialArg from flake.nix) is true for the `*-ci` configurations that
  # build.yml builds. Affinity's wine-wow64 is in no binary cache and takes
  # hours on a GitHub runner, so CI skips it. Local `fr` builds are unaffected.
  enabled = (hostVars.enableAffinity or false) && !ci;

  # Vulkan-Geraetewahl an die Render-GPU von niri koppeln (Hybrid-Laptop meo).
  #
  # Befund 2026-10-14: Der Prefix setzt wined3d auf `renderer=vulkan`
  # (basePrefix.nix, winetricks). Affinity legt sein Haupt-Device ueber D3D11
  # an, und wined3d nimmt dafuer stur den ERSTEN Vulkan-Adapter, den Wine
  # aufzaehlt. Auf meo ist das die Intel Arc (iGPU), waehrend niri und Xwayland
  # im Dock-Modus auf der RTX 4080 laufen. Die Swapchain auf der "falschen" GPU
  # scheitert -> dxgi `DXGID3D10CreateDevice ... hr 0x8007000e` -> Affinity
  # meldet "Failed to create Direct3D device ... 0x8007000E", auch WARP
  # scheitert, Canvas bleibt leer, UI reagiert nicht mehr, nur pkill hilft.
  # vkd3d-proton (D3D12) war NICHT das Problem, dessen Devices kommen sauber.
  #
  # Fix: Mesas implizite Layer VK_LAYER_MESA_device_select sortiert mit
  # MESA_VK_DEVICE_SELECT=<vendor>:<device> dieses Geraet an Position 0 --
  # gilt fuer alle ICDs, also auch den NVIDIA-Treiber. Die PCI-ID wird beim
  # Start aus dem render-drm-device gelesen, das niri-gpu-smart
  # (modules/meo/niri-gpu-smart.nix) in ~/.config/niri/.niri-smart.kdl
  # schreibt. So folgt Affinity automatisch dem Dock-/Mobil-Modus. Fehlt die
  # Datei (meo-work, Fallback-Modus) oder ist die Variable schon gesetzt,
  # bleibt alles wie gehabt. Verifiziert 2026-10-14 mit NVIDIA-only-ICD
  # (VK_DRIVER_FILES) und mit MESA_VK_DEVICE_SELECT=10de:27e0.
  gpuSelectScript = ''
    if [ -z "''${MESA_VK_DEVICE_SELECT:-}" ]; then
      _niri_smart="$HOME/.config/niri/.niri-smart.kdl"
      _node=$(${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*render-drm-device "\(.*\)"/\1/p' "$_niri_smart" 2>/dev/null | tail -n1)
      _sys="/sys/class/drm/''${_node##*/}/device"
      if [ -n "$_node" ] && [ -r "$_sys/vendor" ] && [ -r "$_sys/device" ]; then
        _vid=$(cat "$_sys/vendor"); _did=$(cat "$_sys/device")
        export MESA_VK_DEVICE_SELECT="''${_vid#0x}:''${_did#0x}"
      fi
      unset _niri_smart _node _sys _vid _did
    fi
  '';

  # pkgs.affinity-v3 ist ein symlinkJoin aus Runner (bin/), Desktop-Eintrag
  # und Icons. Der Desktop-Eintrag zeigt direkt auf den Runner-Store-Pfad,
  # deshalb reicht ein Wrapper um bin/ nicht -- Exec= wird mit umgebogen.
  affinity-v3-gpu = pkgs.symlinkJoin {
    name = "affinity-v3-gpu-select";
    paths = [ pkgs.affinity-v3 ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/affinity-v3"
      makeWrapper "${pkgs.affinity-v3}/bin/affinity-v3" "$out/bin/affinity-v3" \
        --run ${lib.escapeShellArg gpuSelectScript}

      desktop="$out/share/applications/affinity-v3.desktop"
      src=$(readlink -f "$desktop")
      rm "$desktop"
      ${pkgs.gnused}/bin/sed "s|^Exec=.*|Exec=$out/bin/affinity-v3 %U|" "$src" > "$desktop"
      grep -q "^Exec=$out/bin/affinity-v3 %U" "$desktop"
    '';
  };
in
lib.mkIf enabled {

  # Wine braucht 32-bit Graphics-Stack für einige Affinity-Calls
  hardware.graphics.enable = lib.mkDefault true;
  hardware.graphics.enable32Bit = lib.mkDefault true;

  # Affinity v3 (Canva-owned) versucht beim Start einen Config-Check gegen
  # affinity-client-config-public.canva.com — wenn der nicht resolved, hängt
  # der Startup ~30s am DNS-Lookup. Block NUR diesen Endpoint.
  #
  # WICHTIG: Wir blocken NICHT canva.com oder api.canva.com — die werden für
  # den OAuth-Login (Canva-Account) gebraucht. Mit zu breitem Block kann man
  # sich in Affinity nicht einloggen.
  networking.extraHosts = ''
    127.0.0.1 affinity-client-config-public.canva.com
  '';

  # Available packages from Meo98/affinity-nix-fork overlay (siehe flake.nix):
  #   pkgs.affinity-v3        — v3 unified app (current, recommended; gepatcht für iGPU)
  #   pkgs.affinity-photo     — v2 Photo (upstream, ungetestet mit fork-patches)
  #   pkgs.affinity-designer  — v2 Designer (upstream, ungetestet)
  #   pkgs.affinity-publisher — v2 Publisher (upstream, ungetestet)
  # affinity-v3-gpu = pkgs.affinity-v3 plus GPU-Auswahl-Wrapper (siehe oben).
  home-manager.users.${username}.home.packages = [
    affinity-v3-gpu
  ];
}
