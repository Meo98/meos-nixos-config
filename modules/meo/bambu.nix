self: super: let
  # ADDED 2026-08-06: Rest-Clipping im Send-Print-Dialog (Toggle-Spalte rechts)
  # besteht auch mit globalem Noto Sans weiter — Noto ist minimal breiter als
  # Bambus Referenzfont "Ubuntu" (Ubuntu 24.04 = deren Test-Plattform, dort
  # werden die hartkodierten Dialogbreiten kalibriert). Per-App-Fontconfig NUR
  # fuer Bambu: sans-serif -> Ubuntu. Das ubuntu-classic-Paket wird nur ueber
  # das <dir> hier eingeblendet, landet NICHT im System-fontconfig.
  # prepend_first noetig, sonst gewinnt der Stylix-Prepend (Noto Sans) aus der
  # includeten fonts.conf.
  bambuFontConf = super.writeText "bambu-fontconfig.conf" ''
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${super.ubuntu-classic}/share/fonts</dir>
      <match target="pattern">
        <test qual="any" name="family"><string>sans-serif</string></test>
        <edit name="family" mode="prepend_first" binding="strong"><string>Ubuntu</string></edit>
      </match>
    </fontconfig>
  '';
in {
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
  
    # HINWEIS 2026-08-04: Per-App-FONTCONFIG_FILE (Noto-Sans-Umbiegung) damals
    # entfernt, weil System-Sans global Noto Sans wurde. 2026-08-06 in neuer
    # Form wieder noetig (Ubuntu statt Noto), siehe bambuFontConf oben.
    profile = ''
      export SSL_CERT_FILE="${super.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${super.glib-networking}/lib/gio/modules/"
      export FONTCONFIG_FILE="${bambuFontConf}"
      # ADDED 2026-08-10: Bambu leitet seine UI-Groesse (em-Skalierung) von der
      # GTK-Systemschrift ab — Stylix setzt Noto Sans 12 statt der ueblichen 10,
      # dadurch wirkt Bambu ~20% groesser als Wayland-Apps (multipliziert sich
      # mit dem 1.6x-Monitor-Scale). 0.83 ≈ 10/12 rechnet das raus, NUR fuer
      # Bambu. 0.75 per Screenshot-Vergleich auf Vivaldi-UI-Textgroesse
      # kalibriert. Zum Testen anderer Werte: GDK_DPI_SCALE=0.9 bambu-studio
      export GDK_DPI_SCALE="''${GDK_DPI_SCALE:-0.75}"
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
