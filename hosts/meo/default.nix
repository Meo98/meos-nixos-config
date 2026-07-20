{ config, pkgs, inputs, lib, username, ... }: {
  imports = [
    ./hardware.nix
    ./host-packages.nix
    ./kanata.nix
    ./affinity.nix
    ../../modules/meo/hyprland-gpu-smart.nix
    ../../modules/meo/android-dev.nix
    ../../modules/meo/dns-override.nix
    ../../modules/meo/synology-mount.nix
  ];

  # Add our custom home-manager modules on top of modules/upstream/home/.
  # This merges with `imports = [./../home]` set in modules/upstream/core/user.nix.
  home-manager.users.${username}.imports = [ ../../modules/meo ];

  programs.kdeconnect.enable = true;

  # --- AUTOMOUNTING ---
  services.udisks2.enable = true;
  environment.systemPackages = [
    pkgs.udiskie
    (pkgs.writeShellScriptBin "travel-power" ''
      case "''${1:-}" in
        on)
          echo quiet > /sys/firmware/acpi/platform_profile 2>/dev/null || true
          for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
            echo 800000 > "$cpu" 2>/dev/null || true
          done
          echo auto > /sys/bus/pci/devices/0000:01:00.0/power/control 2>/dev/null || true
          ;;
        off)
          echo balanced > /sys/firmware/acpi/platform_profile 2>/dev/null || true
          for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
            echo 4800000 > "$cpu" 2>/dev/null || true
          done
          ;;
        *) echo "Usage: travel-power {on|off}" >&2; exit 2 ;;
      esac
    '')
  ];
  systemd.user.services.udiskie = {
    description = "Udiskie Automount Service";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${pkgs.udiskie}/bin/udiskie --no-notify --tray";
  };

  # --- AUDIO FIX (Gegen das Klicken/Knallen) ---
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_hda_intel.power_save_controller=N"
    # OLED-Brightness Fix für ASUS Zephyrus G16 GU605 (Intel Meteor Lake + NVIDIA)
    # Intel DPCD-Backlight aktivieren (=1 für VESA Standard, =3 wäre für HDR)
    "i915.enable_dpcd_backlight=1"
    # NVIDIA Backlight-Handler deaktivieren (blockiert sonst den Intel DPCD-Pfad)
    "nvidia.NVreg_EnableBacklightHandler=0"
    "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=0"
    # PSR-Freeze-Fix (2026-06-21): internes OLED-eDP-1 Panel bleibt bei Idle/DPMS
    # im Intel Panel Self Refresh haengen (i915_psr_status: "PSR1 enabled",
    # Status SRDENT) -> eingefrorenes Lockscreen-Standbild, nur auf eDP, nie auf
    # externem DP-1. PSR komplett abschalten.
    "i915.enable_psr=0"
    # FBC-Freeze-Fix (2026-07-01): gleiches Symptom kehrte trotz PSR=0 zurueck.
    # Live-Diagnose bei eingefrorenem Panel: i915_psr_status "PSR mode: disabled"
    # (PSR sauber aus), aber i915_fbc_status "FBC enabled / Compressing: yes" ->
    # Framebuffer Compression bleibt beim DPMS-Wakeup auf einem komprimierten
    # Standbild haengen, nur eDP-1, nie externer DP. FBC abschalten.
    # Diagnose: sudo cat /sys/kernel/debug/dri/*/i915_fbc_status
    "i915.enable_fbc=0"
    # DC-State-Freeze-Fix (2026-07-01): Freeze kehrte trotz PSR=0 UND FBC=0
    # zurueck. Live-Analyse bei eingefrorenem Panel: KEIN Kernel-Fehler, Hyprland
    # haelt eDP-1 fuer gesund (dpms on), aber weder Modeset noch voller Output-
    # Neuaufbau holen das Bild zurueck -> Wedge sitzt in der i915-Pipe/Power-Well
    # unter dem Compositor. DC5/DC6 (Display Power Wells) sind das letzte
    # SW-unaware Stromsparfeature -> abschalten. Diagnose bei frozen Panel:
    # sudo cat /sys/kernel/debug/dri/*/i915_dmc_info  (DC5->DC6 count)
    "i915.enable_dc=0"
    # HINWEIS 2026-07-16 (Foren-/Upstream-Recherche): (a) Die PSR-Sync-Failures
    # sind laut Intel-Community bis in 2026er-Kernel ungeloest -> Workarounds
    # bleiben noetig. (b) Auf manchen Meteor-Lake-Geraeten half enable_psr=2
    # statt =0 (CachyOS-Forum) — Plan B, falls der Freeze je zurueckkehrt.
    # (c) WICHTIG: Neuere Kernel koennen MTL-Grafik an den `xe`-Treiber statt
    # i915 binden — dann sind ALLE drei i915.*-Params wirkungslos. Check auf meo:
    #   lspci -k | grep -A3 VGA   (Kernel driver in use: i915 oder xe?)
    # Falls xe: Params auf xe.enable_psr=0 etc. umstellen.
  ];

  # --- NVIDIA SUSPEND-FREEZE-FIX (2026-07-10) ---
  # Symptom: beim Zuklappen/Suspend wedged die Maschine auf blauem Konsolen-Screen:
  #   [nvidia-drm] *ERROR* ... Failed to register auto-value-update on pre-wait
  #                value for sync FD semaphore surface
  #   Freezing user space processes failed after 20s (2-3 tasks refusing to freeze)
  # Root Cause: ein GPU-Prozess haengt im uninterruptiblen NVIDIA-Fence-Wait
  # (__nv_drm_semsurf_wait_fence_work_cb). Der Kernel-Freezer kann ihn nicht
  # einfrieren -> Suspend bricht ab -> Hard-Reset noetig. VRAM-Preservation
  # (PreserveVideoMemoryAllocations=1) + nvidia-suspend/resume.service sind bereits
  # aktiv (upstream nvidia-drivers.nix), also NICHT die Ursache.
  # Fix Schritt 1: finegrained RTD3-Runtime-PM abschalten. Upstream markiert es
  # selbst als "Experimental, can cause sleep/suspend to fail" -> die RTD3-
  # Power-State-Uebergaenge racen mit dem Suspend-Freeze. Trade-off: dGPU bleibt
  # bei Idle unter Prime-Offload angeschaltet (etwas mehr Akkuverbrauch), dafuer
  # stabiler Suspend. mkForce, weil upstream finegrained=true hart setzt.
  # Wenn die semsurf-Fence-Fehler danach WEITER auftreten: Schritt 2 = auf das
  # NVIDIA open kernel module wechseln (RTX 4080/Ada wird voll unterstuetzt, ist
  # NVIDIAs empfohlener Pfad auf Treiber 555+ und hat die modernere Wayland-
  # Explicit-Sync-Implementierung):  hardware.nvidia.open = lib.mkForce true;
  hardware.nvidia.powerManagement.finegrained = lib.mkForce false;


  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    # MODIFIED 2026-07-16: Audio-Knackser-Fix modernisiert. Der alte Block
    # (context.properties.node.pause-on-idle=false) betrifft nur Node-Scheduling,
    # NICHT das Device-Suspend, das die Pops verursacht — praktisch wirkungslos.
    # Der etablierte Fix ist die WirePlumber-Regel session.suspend-timeout-
    # seconds=0 (Sink wird nie suspendiert -> kein Knacksen beim Aufwachen).
    wireplumber.extraConfig."51-disable-suspend" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.*"; } ];
          actions.update-props."session.suspend-timeout-seconds" = 0;
        }
      ];
    };
  };

  # --- WEITERE SERVICES ---
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  services.udev.extraRules = ''
    # Keychron Geräte (Vendor ID 3434)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
    # STM32 Bootloader
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", TAG+="uaccess"
    # Keychron Link Dongle
    SUBSYSTEM=="usb", ATTRS{idVendor}=="3434", TAG+="uaccess"
  '';

  # MODIFIED 2026-06-12: hypridle ist als pkgs.hypridle über einen flake-input
  # in environment.systemPackages drin (Quelle nicht eindeutig — vermutlich
  # hyprland-meta-default). Das Package shipt sein Unit mit [Install]
  # WantedBy=graphical-session.target, NixOS legt automatisch den wants-Symlink
  # an → ohne Override würde hypridle bei jedem Boot wieder hochkommen und mit
  # Noctalia v5's idle daemon racen. mkForce [] kappt nur den Auto-Start.
  systemd.user.services.hypridle.wantedBy = lib.mkForce [];

  # --- LOGIND: Zuklappen -> Suspend, ABER nur OHNE externen Monitor ---
  # (2026-07-01) Vorher alles "ignore" (Idle-Screen-off machte noctalia). Da der
  # noctalia Idle-Screen-off jetzt deaktiviert ist (eDP-Freeze-Workaround, siehe
  # kernelParams i915.enable_dc=0 + noctalia.nix), bliebe der interne Panel beim
  # Zuklappen sonst dauerhaft an. Jetzt:
  #   - kein externer Screen  -> Suspend (Panel physisch aus, hitzesicher)
  #   - externer Screen = "docked" -> ignore (Maschine + externer Monitor laufen
  #     weiter; interner Panel bleibt an, aber KEIN DPMS-Freeze-Trigger)
  # lidSwitchExternalPower=suspend, damit es auch am Netzteil (ohne externen)
  # suspendet; "docked" hat Vorrang und greift, sobald ein externer Screen haengt.
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "suspend";
  };

  # --- LOCALE: en_GB fuer Bambu Studio (2026-07-04) ---
  # Bambu Studio (AppImage, wxWidgets) versucht die UI-Sprache "English" auf das
  # glibc-Locale en_GB.UTF-8 zu setzen und wirft sonst "Switching Bambu Studio to
  # language en_GB failed". Der Ubuntu-Rat (locale-gen/dpkg-reconfigure) gilt auf
  # NixOS nicht — Locales sind deklarativ. supportedLocales ersetzt den Default
  # komplett, daher die bestehenden 3 (C, en_US, de_CH aus system.nix) explizit
  # mituebernehmen + en_GB.UTF-8 ergaenzen. Nur meo, weil Bambu nur hier laeuft.
  i18n.supportedLocales = [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "de_CH.UTF-8/UTF-8"
    "en_GB.UTF-8/UTF-8"
  ];

  # --- TRAVEL-MODE: root-helper für CPU/GPU Power-Knobs ---
  security.sudo.extraRules = [{
    users = [ "meo" ];
    commands = [
      { command = "/run/current-system/sw/bin/travel-power"; options = [ "NOPASSWD" ]; }
    ];
  }];

  # --- BENUTZER & GRUPPEN ---
  users.users."meo".extraGroups = [ "dialout" "input" "uinput" ];

  # --- STANDARD ANWENDUNGEN ---
  xdg.mime.defaultApplications = {
    "text/html" = "vivaldi-stable.desktop";
    "x-scheme-handler/http" = "vivaldi-stable.desktop";
    "x-scheme-handler/https" = "vivaldi-stable.desktop";
    "x-scheme-handler/about" = "vivaldi-stable.desktop";
    "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
  };
}
