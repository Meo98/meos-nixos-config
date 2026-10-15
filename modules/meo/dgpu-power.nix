{ pkgs, ... }:
# dGPU-Strommanagement fuer Host meo (ASUS Zephyrus G16 GU605: Intel Arc iGPU
# + NVIDIA RTX 4080). Ergaenzt modules/meo/niri-gpu-smart.nix (Renderer-Wahl
# beim Login: gedockt RTX, mobil iGPU) um vier Dinge:
#
#   1. supergfxd (asus-linux): `supergfxctl -m Integrated` schaltet die RTX
#      hart ab (Module entladen, Geraet vom PCI-Bus) = Reisemodus, in dem
#      kein Prozess sie mehr wachhalten kann. Zurueck mit
#      `supergfxctl -m Hybrid`. Beides braucht Abmelden (supergfxd wartet via
#      logind bis 3 min auf das Ende der Session). Hybrid ist der Default und
#      aendert gegenueber vorher NICHTS; /etc/supergfxd.conf bleibt bewusst
#      der App ueberlassen (kein `settings`), weil supergfxd den gewaehlten
#      Modus dort selbst persistiert -- eine Store-Datei waere read-only.
#      Externer Monitor haengt an der RTX (DP-5 auf card0), im Integrated-
#      Modus also tot: vor dem Docken wieder Hybrid.
#      asusd bewusst NICHT aktiviert: traegt nichts zur GPU bei, und sein
#      Standard-Ladelimit (100 %) wuerde die 80-%-udev-Regel in
#      hosts/meo/default.nix beim Boot ueberschreiben.
#
#   2. on-nvidia <cmd...>: startet eine App auf der RTX, aber NUR, wenn niri
#      gerade auf der iGPU rendert (mobil). Gedockt rendert ohnehin alles auf
#      der RTX, und genau dort haben die __NV_PRIME_*-Variablen Orca/
#      OrcaStudio geblankt (siehe modules/meo/orcastudio.nix) -> dann No-op.
#      Vulkan-Apps sehen die RTX sowieso als Geraet 0 (ICD-Reihenfolge); die
#      Variablen braucht es fuer GLX/EGL-Apps (Blender, Bambu, Orca, FreeCAD,
#      KiCad). MESA_VK_DEVICE_SELECT zusaetzlich, damit der Affinity-Wrapper
#      (hosts/meo/affinity.nix) die RTX statt des niri-Renderers nimmt.
#      Wayland-EGL-Offload mobil ist mit Stand 2026-10-14 noch NICHT
#      verifiziert (Sitzung war gedockt) -- Pruefung: App ueber den
#      "(NVIDIA)"-Eintrag starten, dann `dgpu-status` muss sie als
#      Prozess mit /dev/nvidia* listen.
#
#   3. "(NVIDIA)"-Startereintraege fuer die 3D-/CAD-Apps ueber on-nvidia.
#      Die normalen Eintraege bleiben unveraendert (mobil = iGPU = Akku).
#
#   4. dgpu-status: zeigt, ob die RTX schlaeft (D3cold) und wer sie wachhaelt.
#
# BEFUND 2026-10-14, der dieses Modul begruendet:
#   RTD3 war die ganze Zeit AKTIV: /proc/driver/nvidia/gpus/0000:01:00.0/power
#   meldet "Runtime D3 status: Enabled (fine-grained)". Der Treiber-Default
#   NVreg_DynamicPowerManagement=3 schaltet auf Ada fein-granulares RTD3 von
#   sich aus ein; das mkForce false auf powerManagement.finegrained in
#   hosts/meo/default.nix nimmt nur die udev-Regeln und das explizite 0x02 weg
#   (power/control steht trotzdem auf auto). Der Suspend-Freeze-Fix vom Juli
#   kostet also KEINE 2,8 W, und die 2-4 h Laufzeit mobil kommen nicht daher.
#   Tatsaechlicher Mechanismus: eine gedockt gestartete Session (niri auf der
#   RTX) vererbt den NVIDIA-Kontext an dms/quickshell, Vivaldi, Ghostty und
#   Xwayland (gemessen: 10-14 W bei 2 GB VRAM im Leerlauf). Nach dem Abdocken
#   bleiben diese Prozesse auf der RTX, und sie kann nie nach D3cold, obwohl
#   niri-reload den Renderer fuer NEUE Fenster umstellt. Abhilfe: betroffene
#   Apps neu starten, Neu-Anmelden, oder Integrated-Modus.
let
  nvidiaPci = "0000:01:00.0";

  onNvidia = pkgs.writeShellApplication {
    name = "on-nvidia";
    runtimeInputs = with pkgs; [ coreutils findutils gnused ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "Usage: on-nvidia <kommando> [args...]" >&2
        exit 2
      fi

      pci="/sys/bus/pci/devices/${nvidiaPci}"
      nvidia_node=$(find "$pci/drm" -maxdepth 1 -name 'renderD*' -printf '/dev/dri/%f\n' 2>/dev/null | head -n1 || true)

      # Von niri-smart beim Login geschrieben (modules/meo/niri-gpu-smart.nix);
      # enthaelt den render-drm-device, auf dem niri tatsaechlich laeuft.
      smart="$HOME/.config/niri/.niri-smart.kdl"
      current=$(sed -n 's/^[[:space:]]*render-drm-device "\(.*\)"/\1/p' "$smart" 2>/dev/null | tail -n1 || true)

      if [ -z "''${nvidia_node:-}" ]; then
        echo "on-nvidia: keine NVIDIA-GPU am Bus (Integrated-Modus?), starte ohne Offload" >&2
      elif [ -n "''${current:-}" ] && [ "$current" = "$nvidia_node" ]; then
        # Gedockt: niri rendert schon auf der RTX. PRIME-Variablen hier NICHT
        # setzen -- sie blanken X11-Fenster (Orca-Befund 2026-09-02).
        :
      else
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        vid=$(cat "$pci/vendor"); did=$(cat "$pci/device")
        export MESA_VK_DEVICE_SELECT="''${vid#0x}:''${did#0x}"
      fi
      exec "$@"
    '';
  };

  dgpuStatus = pkgs.writeShellApplication {
    name = "dgpu-status";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep gnused ];
    text = ''
      pci="/sys/bus/pci/devices/${nvidiaPci}"
      status_file="''${XDG_RUNTIME_DIR:-/tmp}/niri-smart.status"
      echo "niri-Renderer: $(sed -n 's/^mode=//p' "$status_file" 2>/dev/null || true)"
      if command -v supergfxctl >/dev/null 2>&1; then
        echo "supergfxctl:   $(supergfxctl -g 2>/dev/null || echo 'daemon nicht erreichbar')"
      fi

      if [ ! -e "$pci" ]; then
        echo "dGPU:          nicht am PCI-Bus (Integrated-Modus) -> zieht keinen Strom"
        exit 0
      fi

      rs=$(cat "$pci/power/runtime_status")
      act=$(( $(cat "$pci/power/runtime_active_time") / 1000 ))
      sus=$(( $(cat "$pci/power/runtime_suspended_time") / 1000 ))
      echo "dGPU:          runtime_status=$rs (control=$(cat "$pci/power/control"))"
      echo "               seit Boot aktiv ''${act}s, schlafend ''${sus}s"
      grep -E 'Runtime D3|Video Memory:' "/proc/driver/nvidia/gpus/${nvidiaPci}/power" 2>/dev/null \
        | sed 's/^/               /' || true

      echo "Prozesse mit offenem /dev/nvidia* (halten die RTX wach):"
      found=0
      for p in /proc/[0-9]*; do
        if find "$p/fd" -maxdepth 1 -lname '/dev/nvidia*' -print -quit 2>/dev/null | grep -q .; then
          found=1
          printf '  %6s  %s\n' "''${p#/proc/}" "$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null | cut -c1-90)"
        fi
      done
      if [ "$found" = 0 ]; then
        echo "  keine"
      elif [ "$rs" != "suspended" ]; then
        echo "Hinweis: solange diese Prozesse laufen, kann die RTX nicht nach D3cold."
        echo "         Mobil: Apps neu starten / neu anmelden, oder: supergfxctl -m Integrated"
      fi
    '';
  };

  # "(NVIDIA)"-Varianten der GPU-hungrigen Apps. Exec/Icon entsprechen den
  # Originaleintraegen im Profil (Stand 2026-10-14).
  nvidiaEntry = { name, desktopName, exec, icon, categories, wmClass ? null }:
    pkgs.makeDesktopItem ({
      name = "${name}-nvidia";
      desktopName = "${desktopName} (NVIDIA)";
      comment = "${desktopName} auf der RTX 4080 starten (Prime-Offload, mobil)";
      exec = "on-nvidia ${exec}";
      inherit icon categories;
      terminal = false;
    } // (if wmClass != null then { startupWMClass = wmClass; } else {}));

  nvidiaEntries = map nvidiaEntry [
    { name = "blender";      desktopName = "Blender";      exec = "blender %f";                   icon = "blender";           categories = [ "Graphics" "3DGraphics" ];              wmClass = "Blender"; }
    { name = "bambu-studio"; desktopName = "BambuStudio";  exec = "bambu-studio %U";              icon = "BambuStudio";       categories = [ "Graphics" "3DGraphics" "Engineering" ]; wmClass = "bambu-studio"; }
    { name = "orca-slicer";  desktopName = "OrcaSlicer";   exec = "orca-slicer %U";               icon = "OrcaSlicer";        categories = [ "Graphics" "3DGraphics" "Engineering" ]; wmClass = "orca-slicer"; }
    { name = "orca-studio";  desktopName = "OrcaStudio";   exec = "orca-studio %F";               icon = "OrcaStudio";        categories = [ "Utility" ];                             wmClass = "BambuStudio_OrcaSlicer"; }
    { name = "freecad";      desktopName = "FreeCAD";      exec = "FreeCAD - --single-instance %F"; icon = "org.freecad.FreeCAD"; categories = [ "Graphics" "Engineering" ];          wmClass = "FreeCAD"; }
    { name = "kicad";        desktopName = "KiCad";        exec = "kicad %f";                     icon = "kicad";             categories = [ "Science" "Electronics" ];               wmClass = "kicad"; }
    { name = "plasticity";   desktopName = "Plasticity";   exec = "Plasticity %U";                icon = "Plasticity";        categories = [ "Graphics" ]; }
    { name = "affinity";     desktopName = "Affinity";     exec = "affinity-v3 %U";               icon = "affinity-v3";       categories = [ "Graphics" ];                            wmClass = "affinity.exe"; }
  ];
in {
  services.supergfxd.enable = true;

  environment.systemPackages = [ onNvidia dgpuStatus ] ++ nvidiaEntries;
}
