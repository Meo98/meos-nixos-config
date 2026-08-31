{ config, pkgs, inputs, lib, username, ... }: {
  imports = [
    ./hardware.nix
    ./host-packages.nix
    ../../modules/meo/kanata.nix
    ./affinity.nix
    ../../modules/meo/hyprland-gpu-smart.nix
    ../../modules/meo/niri-gpu-smart.nix
    ../../modules/meo/android-dev.nix
    ../../modules/meo/dns-override.nix
    ../../modules/meo/synology-mount.nix
    ../../modules/meo/backups.nix
  ];

  # Add our custom home-manager modules on top of modules/upstream/home/.
  # This merges with `imports = [./../home]` set in modules/upstream/core/user.nix.
  # niri wird host-lokal (nicht über modules/meo/default.nix) importiert, damit
  # meo-work (das modules/meo genauso importiert) die niri-Session NICHT bekommt.
  home-manager.users.${username}.imports = [ ../../modules/meo ../../modules/meo/niri ];

  programs.kdeconnect.enable = true;

  # --- niri (Migration 2026-08-27) ---
  # Spec: docs/superpowers/specs/2026-08-27-niri-migration-design.md
  # Bewusst host-lokal statt in modules/upstream/core/packages.nix, damit
  # meo-work den niri-Code zwar im Repo hat, aber nie in seiner Session.
  # Das nixpkgs-Modul liefert Session-Datei, systemd-Units, xdg-Portals
  # (gnome + gtk) und gnome-keyring. Es setzt defaultSession selbst per
  # mkDefault "niri" — die Zuweisung unten ueberschreibt das mit mkForce auf
  # "niri-smart" (den GPU-Wrapper aus modules/meo/niri-gpu-smart.nix).
  programs.niri.enable = true;

  # MODIFIED 2026-08-27: von "hyprland-smart" auf "niri-smart" umgestellt
  # (Ende der Migration, Task 11). Rueckweg ohne Rebuild: in SDDM unten links
  # die Session "Hyprland (Smart GPU)" waehlen. Die Hyprland-Module bleiben
  # vollstaendig im Repo. mkForce bleibt noetig: das niri-Modul setzt
  # defaultSession selbst per mkDefault "niri" — mkForce nagelt hier
  # stattdessen "niri-smart" fest. Hyprland selbst setzt defaultSession nicht.
  services.displayManager.defaultSession = lib.mkForce "niri-smart";

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

  # --- AKKU: eDP-1 60Hz am Akku, 240Hz am Netz (2026-07-21) ---
  # 240Hz-Scanout kostet auf dem OLED spuerbar Strom (2-4W), und weil PSR wegen
  # des eDP-Freeze aus ist, laeuft die Display-Pipe wirklich permanent auf 240Hz.
  # Event-getrieben via `upower --monitor` (kein Polling). Fasst NUR eDP-1 an,
  # Werte muessen zu variables.nix extraMonitorSettings passen (0x0, scale 1.6).
  # Limitation: Hyprland-Config-Reload setzt wieder 240Hz; der naechste
  # AC-Wechsel korrigiert das.
  systemd.user.services.edp-refresh-switcher = {
    description = "eDP-1 refresh: 60Hz on battery, 240Hz on AC";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
      ExecStart = pkgs.writeShellScript "edp-refresh-switcher" ''
        export PATH=/run/current-system/sw/bin:$PATH
        # MODIFIED 2026-08-27 (niri-Migration): erkennt die laufende Session und
        # spricht entweder niri oder Hyprland an. Vorher hart auf hyprctl.
        #
        # Einschraenkung unveraendert: `niri msg output` ist laut --help
        # ausdruecklich temporaer und wird bei einer Config-Aenderung vergessen —
        # genau wie ein Hyprland-Config-Reload wieder 240Hz setzt. Der naechste
        # AC-Wechsel korrigiert das.
        set_rate() {
          rate="$1"
          # Fallback als Glob statt fixem Namen: niris Socket heisst
          # niri.<wayland-display>.<pid>.sock (src/ipc/server.rs), ein fest
          # notierter Name kann also nie matchen. Der Glob wurde dem Loeschen
          # vorgezogen, weil NIRI_SOCKET nur in der importierten Session-Env
          # steht — startet der Service je ausserhalb davon, greift der Glob.
          # Trifft er auf einen verwaisten Socket, scheitert `niri msg` und der
          # Hyprland-Zweig uebernimmt wie bisher.
          if [ -n "''${NIRI_SOCKET:-}" ] || ls "$XDG_RUNTIME_DIR"/niri.*.sock >/dev/null 2>&1; then
            niri msg output eDP-1 mode "2560x1600@$rate" >/dev/null 2>&1 && return 0
          fi
          HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
          export HYPRLAND_INSTANCE_SIGNATURE
          [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || return 0
          hyprctl keyword monitor "eDP-1,2560x1600@$rate,0x0,1.6" >/dev/null
        }
        apply() {
          if [ "$(cat /sys/class/power_supply/ACAD/online)" = "1" ]; then
            [ "$last" = ac ] || { last=ac; set_rate 240; }
          else
            [ "$last" = bat ] || { last=bat; set_rate 60; }
          fi
        }
        last=""
        apply
        upower --monitor | while read -r _; do apply; done
      '';
    };
  };

  # --- AUDIO FIX (Gegen das Klicken/Knallen) ---
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_hda_intel.power_save_controller=N"
    # OLED-Brightness Fix für ASUS Zephyrus G16 GU605 (Intel Meteor Lake + NVIDIA)
    # MODIFIED 2026-07-21: =1 (VESA) -> =3 (Intel HDR Interface). Mit =1 war die
    # Helligkeit wirkungslos (Panel dauerhaft volle Luminanz, intel_backlight-
    # Writes ohne Effekt). Kernel-Log sagt es woertlich: "Panel is missing HDR
    # static metadata. ... If your backlight controls don't work try booting
    # with i915.enable_dpcd_backlight=3." -> Das GU605-OLED kann nur Intels
    # proprietaeres HDR-Backlight-AUX-Interface, auch fuer SDR-Brightness.
    "i915.enable_dpcd_backlight=3"
    # NVIDIA Backlight-Handler deaktivieren (blockiert sonst den Intel DPCD-Pfad)
    # HINWEIS 2026-07-21: Param existiert im aktuellen Treiber nicht mehr
    # ("unknown parameter ... ignored" im Kernel-Log), /sys/class/backlight/
    # nvidia_0 taucht daher wieder auf. Harmlos, aber Brightness-Tools koennen
    # das falsche Device erwischen -> ggf. explizit intel_backlight ansteuern.
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
  # Schritt 2 GESCHEITERT (2026-07-22): open kernel module (595.84) getestet,
  # Suspend haengte sich beim ZWEITEN Zyklus auf — anderes Muster als der alte
  # semsurf-Bug (1. Suspend/Resume ok; 2. Versuch hing VOR dem Userspace-Freeze,
  # System lief blind weiter, Hard-Reset noetig; journal des Boots: 09:42:31
  # "Starting System Suspend..." ohne jede Folgezeile). Verdacht: GPU-Prozess
  # nach Resume #1 in unkillbarem Wait, evtl. weil open+595 automatisch auf
  # powerManagement.kernelSuspendNotifier umschaltet (nvidia-suspend/resume-
  # Units mit VRAM-Preservation entfallen). Falls je nochmal probiert:
  # open=true + kernelSuspendNotifier=false waere die naechste Variante.
  # Bis dahin: proprietaeres Modul = known-good.


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
    # Akku-Ladelimit 80% (2026-07-21): Akku ist bereits auf 80.5% Design-Kapazitaet
    # (72.5/90 Wh) degradiert. Limit bremst weitere Alterung; asus-wmi setzt das
    # Attribut beim Boot auf 100 zurueck, daher per udev bei jedem BAT1-Event neu.
    ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT1", ATTR{charge_control_end_threshold}="80"
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

  # --- LOCK VOR SUSPEND (2026-08-27, niri-Migration) ---
  # Bis hierher sperrte hypridle die Session vor dem Suspend
  # (before_sleep_cmd = "loginctl lock-session", modules/upstream/home/hyprland/
  # hypridle.nix). hypridle haengt aber an systemdTarget =
  # "hyprland-session.target" und startet unter niri gar nicht. Ohne diesen
  # Hook wuerde lidSwitch = "suspend" die Maschine UNGESPERRT schlafen legen;
  # Noctalias eigener Idle-Lock ist ein 600-s-Timer und deckt keinen
  # Suspend-Hook ab.
  #
  # Bewusst SYSTEM-Ebene und compositor-neutral: greift unter niri UND unter
  # Hyprland (Rollback-Session). Unter Hyprland sperrt hypridle zusaetzlich —
  # doppeltes Sperren ist idempotent und harmlos, das ist KEIN Grund, den Hook
  # wieder "wegzuoptimieren". `lock-sessions` (Plural) statt `lock-session`,
  # weil hier root ohne eigene Session laeuft.
  #
  # Das kurze sleep hat denselben Grund wie beim Bind Mod+Alt+L
  # (modules/meo/niri/binds-apps.nix): der Compositor braucht einen Moment, um
  # das Lock-Surface zu committen, bevor die Maschine runtergeht.
  systemd.services.lock-before-sleep = {
    description = "Lock all sessions before suspend/hibernate";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      # MODIFIED 2026-08-27: TimeoutStartSec ergaenzt. `loginctl lock-sessions`
      # kehrt normalerweise sofort zurueck, haengt aber am System-Bus. Ist der
      # wedged, wuerde der systemd-Default (90s) den Suspend so lange blockieren,
      # bevor `|| true` ueberhaupt erreicht wird — beim Zuklappen also 1.5 Minuten
      # mit laufender Maschine im Rucksack. 5s reichen fuer den Normalfall.
      TimeoutStartSec = 5;
      ExecStart = pkgs.writeShellScript "lock-before-sleep" ''
        ${config.systemd.package}/bin/loginctl lock-sessions || true
        ${pkgs.coreutils}/bin/sleep 0.5
      '';
    };
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

  # --- DISK-SWAP als Überlauf hinter zram (Notnetz gegen OOM-Kills) ---
  # Gleiches Muster wie auf meo-work: zram (50% ≈ 15 GB, Prio 5) füllt sich
  # zuerst, kalte Seiten laufen danach in die Swap-Datei über (Prio negativ).
  # Anlass 2026-08-14: Blender in 3 der letzten 4 Boots per OOM-Killer
  # abgeschossen (bis 24 GB RSS, Mondlampen-Szene), Bambu Studio 2× beim
  # Slicen (18-23 GB RSS) — 30 GB RAM + zram allein reichen für die Peaks
  # nicht. 32 GiB Puffer; Root (ext4, NVMe) hat >600 GB frei.
  swapDevices = [{
    device = "/swapfile";
    size = 32 * 1024;   # 32 GiB
  }];
  # zram mag Einzelseiten (kein Read-ahead beim Swap-In) — wie auf meo-work.
  boot.kernel.sysctl."vm.page-cluster" = 0;

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
