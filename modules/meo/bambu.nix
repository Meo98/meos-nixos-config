self: super: {
  bambu-studio = super.appimageTools.wrapType2 rec {
    name = "BambuStudio";
    pname = "bambu-studio";
    # MODIFIED 2026-07-04: von 02.02.02.56 auf neueste stabile 02.07.01.62 gebumpt.
    # MODIFIED 2026-08-03: auf 02.08.00.50 (Public BETA) gebumpt wegen
    # abgeschnittener Popups/Dialoge (Send-Print-Dialog, Dual-Nozzle-Layout X2D);
    # Release-Notes nennen "dialog centering" + UI-Fixes. ACHTUNG: 3MF aus der
    # Beta laesst sich nicht zu MakerWorld hochladen. Revert: version/buildstamp/
    # sha256 auf den 02.07.01.62-Stand aus git zuruecksetzen.
    # Namensschema der AppImage hat sich geaendert: frueher
    # "Bambu_Studio_ubuntu-${ubuntu_version}.AppImage", jetzt
    # "BambuStudio_ubuntu24.04-v${version}-${buildstamp}.AppImage".
    # Bei kuenftigem Bump: neue Version + buildstamp aus dem GitHub-Release holen
    #   gh release view --repo bambulab/BambuStudio --json tagName,assets
    # dann Hash: nix store prefetch-file --hash-type sha256 <url>
    version = "02.08.00.50";
    buildstamp = "20260625193201";

    src = super.fetchurl {
      url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-${buildstamp}.AppImage";
      sha256 = "sha256-JGy2ua2TtLSmX2MTJN1/CYvyEZiiw5g36RqmoDk+TdQ=";
    };
  
    profile = ''
      export SSL_CERT_FILE="${super.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${super.glib-networking}/lib/gio/modules/"
    '';
    
    extraPkgs = pkgs: with pkgs; [
      cacert
      glib
      glib-networking
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      webkitgtk_4_1
    ];

    # ADDED 2026-08-03: wrapType2 installiert nur $out/bin — Desktop-Datei und
    # Icon stecken im AppImage-Root und muessen fuer den Launcher-Eintrag
    # explizit nach $out/share kopiert werden.
    extraInstallCommands = let
      appimageContents = super.appimageTools.extract { inherit pname version src; };
    in ''
      install -Dm444 ${appimageContents}/BambuStudio.desktop \
        $out/share/applications/BambuStudio.desktop
      install -Dm444 ${appimageContents}/BambuStudio.png \
        $out/share/icons/hicolor/192x192/apps/BambuStudio.png
      substituteInPlace $out/share/applications/BambuStudio.desktop \
        --replace-fail 'Exec=AppRun %U' 'Exec=bambu-studio %U'
    '';
  };
}
