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
      # ADDED 2026-11-22: leere 3D-Ansicht auf meo (RTX 4080, Treiber 595).
      # Das AppRun der AppImage zwingt unter Wayland + NVIDIA-Treiber > 555
      # Mesa/zink (__GLX_VENDOR_LIBRARY_NAME=mesa, MESA_LOADER_DRIVER_OVERRIDE=
      # zink) -> "cannot make the GL context current", Ansicht bleibt grau.
      # Ohne zink laeuft die 3D-Ansicht nativ unter Wayland (getestet mit
      # Wuerfel). GDK_BACKEND=x11 (wie frueher bei OrcaStudio) ging auch,
      # stuerzte aber beim Beenden in libnvidia-glcore ab -> bewusst nicht.
      export ZINK_DISABLE_OVERRIDE=1
      # Startseite / Orca-Cloud / Bambu-Login (WebKit) blieben sonst leer
      # (getestet: ohne diese Variable leer, mit ihr sichtbar).
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
      # NIE die __NV_PRIME_*-Variablen setzen (siehe dgpu-power.nix).
    '';

    extraPkgs = pkgs: with pkgs; [
      cacert
      glib
      glib-networking
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      webkitgtk_4_1
      libsoup_3 # Binary linkt libsoup-3.0.so.0 direkt; wrapType2 nimmt nur gelistete Pakete in den LD-Pfad
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
