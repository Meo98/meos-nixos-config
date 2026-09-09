self: super: {
  # ADDED 2026-09-07: JLCONE = offizieller JLCPCB-Desktop-Client (Electron)
  # fuer PCB/PCBA/CNC-Bestellungen. Grund: App-exklusive Rabatte (Coupon-
  # Paket bei Installation + zufaelliger 1-20-$-Sofortrabatt beim Checkout
  # in der App), genutzt fuer die PicoStack-Bestellungen.
  #
  # Es gibt nur ein .deb (kein AppImage); URL + Hash stammen aus dem
  # AUR-Paket jlcone-bin (Version dort gepflegt). Bei Version-Bump:
  #   curl -A "Mozilla/5.0" -o jlcone.deb \
  #     https://rs.jlcone.com/static/APP/app_version/jlcone-<ver>.deb
  #   nix hash file --sri jlcone.deb
  # Der CDN lehnt curls Standard-User-Agent ab, daher curlOptsList.
  jlcone = super.stdenv.mkDerivation rec {
    pname = "jlcone";
    version = "1.0.69";

    src = super.fetchurl {
      url = "https://rs.jlcone.com/static/APP/app_version/jlcone-${version}.deb";
      sha256 = "01c5778da3ead64bfb3058895ed13168b910d51755b18e645d5f3898edc4575a";
      curlOptsList = [ "--user-agent" "Mozilla/5.0" ];
    };

    nativeBuildInputs = with super; [
      dpkg
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = with super; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libdrm
      libgbm
      libnotify
      libsecret
      libxkbcommon
      mesa
      nspr
      nss
      pango
      systemd # libudev
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libxshmfence
    ];

    # Electron bringt eigene libffmpeg.so etc. mit -- die sollen aus dem
    # eigenen Verzeichnis kommen, nicht aus dem Store.
    runtimeDependencies = with super; [ (super.lib.getLib systemd) ];

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/share
      cp -r opt $out/opt
      [ -d usr/share ] && cp -r usr/share/* $out/share/ || true
      # Upstream liefert teils world-writable Dateien (s. AUR-PKGBUILD)
      chmod -R go-w $out/opt

      # libglvnd via LD_LIBRARY_PATH: ANGLEs eigene libEGL.so dlopent zur
      # Laufzeit das native libEGL.so.1 (GLVND-Dispatcher). Ohne es stirbt
      # der GPU-Prozess ("Could not dlopen native EGL") und Chromium faellt
      # auf Software-Rendering zurueck -- der PCB-Viewer ruckelt. mesa in
      # buildInputs reicht nicht (libEGL.so.1 liegt in libglvnd), und
      # runtimeDependencies greift nicht (autoPatchelf patcht Executables,
      # der dlopen kommt aber aus der Bibliothek; RUNPATH ist nicht
      # transitiv). Nachgewiesen 2026-09-07 mit --enable-logging=stderr.
      makeWrapper $out/opt/JLCONE/jlcone $out/bin/jlcone \
        --add-flags "--ozone-platform-hint=auto" \
        --prefix LD_LIBRARY_PATH : "${super.lib.makeLibraryPath [ super.libglvnd ]}" \
        --argv0 jlcone

      # Desktop-Eintrag auf den Wrapper zeigen lassen, falls vorhanden
      if [ -f $out/share/applications/jlcone.desktop ]; then
        substituteInPlace $out/share/applications/jlcone.desktop \
          --replace-warn "/opt/JLCONE/jlcone" "jlcone"
      fi
      runHook postInstall
    '';

    # Der Chromium-SUID-Sandbox-Helfer funktioniert im Store nicht;
    # Electron faellt auf die User-Namespace-Sandbox zurueck (auf NixOS
    # aktiv). Nur falls der Start je mit Sandbox-Fehler abbricht:
    # jlcone --no-sandbox.
    dontWrapGApps = false;

    meta = with super.lib; {
      description = "JLCPCB desktop client (PCB/PCBA/CNC orders)";
      homepage = "https://jlcone.com";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };
}
