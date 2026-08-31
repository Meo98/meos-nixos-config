{
  description = "MeoNix — Meo's NixOS configuration (meo + meo-work hosts). Based on zaneyos modules vendored in modules/upstream/.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Separater Pin nur fuer FreeCAD: auf dem Haupt-Pin (20260715) ist die
    # Kette pdal->vtk->freecad kaputt (GCC15/GDAL-Buildfehler, nicht in Hydra
    # gecached). Neueres unstable hat den Fix + Binary-Cache. Kann beim
    # naechsten grossen nixpkgs-Bump wieder entfernt werden (dann freecad
    # regulaer aus pkgs beziehen).
    nixpkgs-freecad.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=latest";

    # Vorgebaute nix-index-DB (woechentlich) fuer "command not found"-Vorschlaege
    # + comma (`, <tool>` startet ein Paket ephemer). Spart das teure lokale
    # nix-index-Generieren.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 2026-06-12: repo renamed upstream (noctalia-shell → noctalia) for the v5
    # rewrite. v5 is a native C++ Wayland shell (no Qt/Quickshell). The official
    # home-manager module lives at inputs.noctalia.homeModules.default and
    # generates ~/.config/noctalia/config.toml from programs.noctalia.settings.
    noctalia = {
      # MODIFIED 2026-07-16: auf Release-Tag gepinnt statt master-HEAD.
      # 'nix flake update' zog master-Commits NACH beta2 mit kaputter
      # Test-Suite (narrowing conversion in config_schema_roundtrip_test.cpp)
      # -> Build-Abbruch. Releases sind getestet, master ist Lotterie.
      # Bei neuem Release: Tag hier bumpen + nix flake lock --update-input noctalia
      # MODIFIED 2026-07-18: beta2 -> beta.3. beta2 wedgte nach Suspend/Resume
      # den EGL-Context (guilty-context-reset -> EGL_BAD_CONTEXT-Loop -> Lock-
      # screen eingefroren, nur Reboot half). beta.3 fixt das Resume-Redraw
      # (Commits 918f0549 "redraw active lockscreen after resume" + b6d8447e
      # "defer surface redraws on resume and unlock").
      #
      # MODIFIED 2026-08-31: beta.3 -> beta.10. Der Pin war sechs Wochen und
      # sieben Betas alt; v5 ist eine laufende Neuentwicklung, und die Betas
      # dazwischen tragen echte Fixes. Vor dem Bump alle Release-Notes von
      # beta.4 bis beta.10 auf Breaking Changes geprueft: es gibt genau EINE
      # (beta.9, Plugin-Manifeste brauchen jetzt eine kanonische version).
      # Am Konfigurations-Schema hat sich nichts geaendert, die deklarativen
      # settings in modules/upstream/home/noctalia.nix bleiben also gueltig.
      #
      # Kontext: Anlass war die Ueberlegung, den Shell ganz zu wechseln
      # (DankMaterialShell). Beim Pruefen kam heraus, dass DMS' HM-Modul nur
      # elf Optionen kennt und KEINE Einstellungsdatei schreibt — Leiste,
      # Lock- und Idle-Zeiten waeren GUI-Zustand geworden, samt der
      # eDP-Freeze-Sperre (idleScreenOff) auf meo. Deshalb zuerst die billige
      # Erklaerung ausschliessen: veralteter Pin statt falscher Shell.
      url = "github:noctalia-dev/noctalia/v5.0.0-beta.10";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DankMaterialShell — Shell-Alternative zu Noctalia, gated ueber
    # barChoice in hosts/<host>/variables.nix.
    # Spec: docs/superpowers/specs/2026-08-31-dms-migration-design.md
    #
    # Wie bei noctalia bewusst auf einen Release-Tag gepinnt statt auf
    # master-HEAD: Releases sind getestet, master ist Lotterie.
    # v1.5.3 ist der aktuellste Release-Tag (geprueft 2026-08-31 ueber die
    # GitHub-API).
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell/v1.5.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    awww = {
      url = "git+https://codeberg.org/LGFae/awww";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
      # MODIFIED 2026-08-20: home-manager auf unser nixpkgs-following HM gepinnt,
      # sonst zog zen-browser einen zweiten home-manager-Baum (lock-node
      # home-manager_2). Spart einen redundanten Input.
      inputs.home-manager.follows = "home-manager";
    };

    # Fork of mrshmllow/affinity-nix mit fixes für Intel Iris Xe (meo-work):
    # - CanvaSignInPatch entfernt (fixt 0xC06D007E Startup-Crash)
    # - d2d1.dll native lib aus v0.3.0 mit Bezier recursion/split-budget patches
    #   (fixt Double-Click-Hang auf SVG-importierten Symbolen)
    # - DXVK 2.4.1 zusammen mit vkd3d-proton (fixt WARP-Software-Renderer-
    #   Fallback der CPU sättigt)
    affinity-nix = {
      url = "github:Meo98/affinity-nix-fork";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sddm-noctalia = {
      url = "github:mahaveergurjar/sddm/noctalia";
      flake = false;
    };

  };

  outputs = inputs@{ self, nixpkgs, nix-flatpak, ... }:
  let
    lib = nixpkgs.lib;

    system = "x86_64-linux";
    username = "meo";
    defaultHost = "meo";
    defaultProfile = "nvidia-laptop";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    mkNixosConfig = { host ? defaultHost, profile ? defaultProfile, nixosTarget ? profile }:
      lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs username host profile nixosTarget;
        };

        modules = [
          ./hosts/${host}
          ./modules/upstream/core/overlays.nix
          ./modules/upstream/profiles/${profile}
          nix-flatpak.nixosModules.nix-flatpak
        ];
      };
  in
  {
    nixosConfigurations = {
      # Home-PC: Nvidia Laptop (ASUS Zephyrus G16 GU605 — Intel Meteor Lake + NVIDIA)
      meo      = mkNixosConfig { profile = "nvidia-laptop"; nixosTarget = "meo"; };

      # Arbeitslaptop: Intel i7-1165G7 + Intel Iris Xe (kein dedizierter GPU)
      meo-work = mkNixosConfig { host = "meo-work"; profile = "intel"; nixosTarget = "meo-work"; };
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        python312
        python312Packages.pip
        python312Packages.streamlit
        python312Packages.venvShellHook
      ];

      venvDir = ".venv";

      postVenvCreation = ''
        if [ -f requirements.txt ]; then
          pip install -r requirements.txt
        fi
      '';

      postShellHook = ''
        echo "✅ DevShell ready"
        echo "Python: $(python --version)"
        echo "Pip: $(pip --version)"
        echo "Streamlit: $(streamlit --version)"
      '';
    };

    # MODIFIED 2026-08-20: alejandra-Flake-Input entfernt; pkgs.alejandra ist
    # bereits in core/packages.nix. Spart die Input-Kette (fenix_2,
    # rust-analyzer-src_2, flakeCompat). `nix fmt` läuft unverändert.
    formatter.x86_64-linux = pkgs.alejandra;
  };
}
