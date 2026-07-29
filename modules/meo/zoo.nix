self: super: {
  zoo-design-studio = super.appimageTools.wrapType2 rec {
    name = "ZooDesignStudio";
    pname = "zoo-design-studio";
    # Zoo Design Studio (zoo.dev, ehem. KittyCAD) — CAD mit Text-to-CAD/KCL.
    # Bei kuenftigem Bump: neue Version aus dem GitHub-Release holen
    #   gh release view --repo KittyCAD/modeling-app --json tagName,assets
    # dann Hash: nix store prefetch-file --hash-type sha256 <url>
    version = "1.3.7";

    src = super.fetchurl {
      url = "https://github.com/KittyCAD/modeling-app/releases/download/v${version}/Zoo.Design.Studio-${version}-x86_64-linux.AppImage";
      sha256 = "sha256-VwHWYrt3YV4yvObMhwb5h5o0JfUl4efvaJ0Bm7j68Yk=";
    };

    profile = ''
      export SSL_CERT_FILE="${super.cacert}/etc/ssl/certs/ca-bundle.crt"
    '';

    extraPkgs = pkgs: with pkgs; [
      cacert
    ];
  };
}
