self: super: {
  # ADDED 2026-11-21: OrcaSlicer 2.5.2 als offizielle AppImage statt nixpkgs
  # (dort noch 2.4.2, from-source). Grund: Python-Plugins gibt es erst ab 2.5.
  # Die AppImage bringt das eingebettete CPython und `uv` (fuer Plugin-
  # Abhaengigkeiten) mit; im FHS-Wrapper finden beide ihre Pfade.
  # Das Overlay ersetzt `orca-slicer` selbst, die Paketzeile in
  # hosts/*/host-packages.nix bleibt gleich.
  # Zurueck auf nixpkgs: import-Zeile in hosts/*/host-packages.nix entfernen,
  # sobald nixpkgs >= 2.5 hat (`nix eval nixpkgs#orca-slicer.version`).
  # Version-Bump: gh release view --repo OrcaSlicer/OrcaSlicer, dann
  #   nix store prefetch-file --hash-type sha256 <url>
  # und gegen das `digest`-Feld des Release-Assets vergleichen.
  orca-slicer = super.appimageTools.wrapType2 rec {
    pname = "orca-slicer";
    version = "2.5.2";

    src = super.fetchurl {
      url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v${version}/OrcaSlicer_Linux_AppImage_Ubuntu2404_V${version}.AppImage";
      # verifiziert gegen das GitHub-Asset-Digest (22fa8888…b0a870)
      sha256 = "sha256-IvqIiE3sP9vSnpDLqZEvz/b7V6YLG9wabBicYaawqHA=";
    };

    profile = ''
      export SSL_CERT_FILE="${super.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${super.glib-networking}/lib/gio/modules/"
      # wie im nixpkgs-Paket: WebKit-Ansichten (Startseite, Plugin-Browser)
      # bleiben sonst unter Wayland/NVIDIA leer
      export WEBKIT_DISABLE_COMPOSITING_MODE=1
    '';

    extraPkgs = pkgs: with pkgs; [
      cacert
      glib
      glib-networking
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      webkitgtk_4_1
      libsoup_3 # Binary linkt libsoup-3.0.so.0 direkt (siehe orcastudio.nix)
    ];

    # Desktop-Datei + Icon stecken im AppImage-Root (wrapType2 installiert nur
    # $out/bin).
    extraInstallCommands = let
      appimageContents = super.appimageTools.extract { inherit pname version src; };
    in ''
      install -Dm444 ${appimageContents}/com.orcaslicer.OrcaSlicer.desktop \
        $out/share/applications/com.orcaslicer.OrcaSlicer.desktop
      install -Dm444 ${appimageContents}/OrcaSlicer.png \
        $out/share/icons/hicolor/192x192/apps/OrcaSlicer.png
      # Die Desktop-Datei der AppImage ist magerer als die von nixpkgs: ohne
      # `x-scheme-handler/orcaslicer` kommt der Browser-Login von Orca Cloud
      # (noetig fuer Plugins) nicht in die App zurueck.
      substituteInPlace $out/share/applications/com.orcaslicer.OrcaSlicer.desktop \
        --replace-fail 'Exec=AppRun %F' 'Exec=orca-slicer %U' \
        --replace-fail 'Categories=Utility;' 'Categories=Graphics;3DGraphics;Engineering;' \
        --replace-fail 'application/x-amf;' 'application/x-amf;model/3mf;model/step;x-scheme-handler/orcaslicer;'
      echo 'StartupWMClass=orca-slicer' >> $out/share/applications/com.orcaslicer.OrcaSlicer.desktop
    '';
  };
}
