self: super: {
  bambu-studio = super.appimageTools.wrapType2 rec {
    name = "BambuStudio";
    pname = "bambu-studio";
    # MODIFIED 2026-07-04: von 02.02.02.56 auf neueste stabile 02.07.01.62 gebumpt.
    # Namensschema der AppImage hat sich geaendert: frueher
    # "Bambu_Studio_ubuntu-${ubuntu_version}.AppImage", jetzt
    # "BambuStudio_ubuntu24.04-v${version}-${buildstamp}.AppImage".
    # Bei kuenftigem Bump: neue Version + buildstamp aus dem GitHub-Release holen
    #   gh release view --repo bambulab/BambuStudio --json tagName,assets
    # dann Hash: nix store prefetch-file --hash-type sha256 <url>
    version = "02.07.01.62";
    buildstamp = "20260616195227";

    src = super.fetchurl {
      url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-${buildstamp}.AppImage";
      sha256 = "sha256-+pi2CFMt+7uysJMUg6rEHlf7GcF1osx719Uo1eD7soc=";
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
  };
}
