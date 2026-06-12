{
  description = "MeoNix — Meo's NixOS configuration (meo + meo-work hosts). Based on zaneyos modules vendored in modules/upstream/.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=latest";

    nvf = {
      url = "github:notashelf/nvf";
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
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # quickshell input retained — other modules may still want it, but Noctalia
    # v5 itself does not. Safe to remove if nothing else depends on it after the
    # v5 cutover.
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
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

    alejandra = {
      url = "github:kamadorueda/alejandra";
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

    formatter.x86_64-linux = inputs.alejandra.packages.x86_64-linux.default;
  };
}
