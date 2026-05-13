{
  description = "ZaneyOS Unstable";

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

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # affinity-nix = {
    #   url = "path:/home/meo/affinity-nix-fork";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

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
          ./modules/core/overlays.nix
          ./profiles/${profile}
          nix-flatpak.nixosModules.nix-flatpak
        ];
      };
  in
  {
    nixosConfigurations = {
      amd           = mkNixosConfig { profile = "amd"; };
      nvidia        = mkNixosConfig { profile = "nvidia"; };
      nvidia-laptop = mkNixosConfig { profile = "nvidia-laptop"; };
      amd-hybrid    = mkNixosConfig { profile = "amd-hybrid"; };
      amd-nvidia-hybrid = mkNixosConfig { profile = "amd-nvidia-hybrid"; };
      intel         = mkNixosConfig { profile = "intel"; };
      vm            = mkNixosConfig { profile = "vm"; };

      # Home-PC: Nvidia Laptop
      meo           = mkNixosConfig { profile = "nvidia-laptop"; };

      # Arbeitslaptop: Intel i7-1165G7 + Intel Iris Xe (kein dedizierter GPU)
      meo-work      = mkNixosConfig { host = "meo-work"; profile = "intel"; nixosTarget = "meo-work"; };
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
