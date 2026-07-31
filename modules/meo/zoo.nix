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

    # wrapType2 liefert nur das Binary — Desktop-Eintrag + Icon aus dem
    # AppImage extrahieren, damit die App im Launcher auftaucht.
    extraInstallCommands =
      let
        appimageContents = super.appimageTools.extract { inherit pname version src; };
      in ''
        install -Dm444 ${appimageContents}/zoo-modeling-app.desktop \
          $out/share/applications/zoo-design-studio.desktop
        install -Dm444 ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/zoo-modeling-app.png \
          $out/share/icons/hicolor/1024x1024/apps/zoo-modeling-app.png
        substituteInPlace $out/share/applications/zoo-design-studio.desktop \
          --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=zoo-design-studio %U'
      '';

    extraPkgs = pkgs: with pkgs; [
      cacert
    ];
  };
}
