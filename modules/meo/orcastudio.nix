self: super: let
  # ADDED 2026-08-20: OrcaStudio = Community-Fork (jarczakpawel) von Bambu
  # Studio 02.08.01.55 mit Orca-Features (Kalibrier-Tools etc.) UND voller
  # Bambu-Cloud-Anbindung — der Linux-Ersatz fuer den fehlenden Bambu-Connect
  # (Linux offiziell "Under Development"). Läuft parallel zu bambu-studio und
  # orca-slicer. AUR-Pendant: orca-bambustudio-appimage.
  # Bei Version-Bump: Release + SHA256SUMS_ubuntu24.04_appimage.txt von
  #   gh release view --repo jarczakpawel/OrcaStudio
  # dann Hash: nix store prefetch-file --hash-type sha256 <url>
  # und gegen die offizielle SHA256SUMS-Datei vergleichen!
  #
  # Fontconfig: gleiche Begruendung wie in bambu.nix (Basis ist Bambu Studio,
  # gleiche hartkodierte Dialogbreiten, kalibriert auf Ubuntu-Font).
  orcaStudioFontConf = super.writeText "orcastudio-fontconfig.conf" ''
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
  orca-studio = super.appimageTools.wrapType2 rec {
    name = "OrcaStudio";
    pname = "orca-studio";
    version = "02.08.01.55-p3";

    src = super.fetchurl {
      url = "https://github.com/jarczakpawel/OrcaStudio/releases/download/v${version}/OrcaStudio_Linux_AppImage_ubuntu24.04_amd64_${version}.AppImage";
      # verifiziert gegen SHA256SUMS_ubuntu24.04_appimage.txt des Releases
      # (508c5fc15ecba9...d457cf95)
      sha256 = "sha256-UIxfwV7Lqcp8r4iWO1PfleV8Pjxv/Mxl6o8L9tRXz5U=";
    };

    profile = ''
      export SSL_CERT_FILE="${super.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${super.glib-networking}/lib/gio/modules/"
      export FONTCONFIG_FILE="${orcaStudioFontConf}"
      # Gleicher em-Skalierungs-Fix wie bambu.nix: Stylix' 12pt-Systemfont
      # macht die UI sonst ~20% zu gross (siehe Kommentar dort).
      export GDK_DPI_SCALE="''${GDK_DPI_SCALE:-0.75}"
      # ADDED 2026-09-02: X11 erzwingen, damit die App auf der RTX 4080 rendert
      # statt auf der Intel-Arc-iGPU (nativer Wayland/EGL-Pfad landete auf
      # "Mesa Intel(R) Arc(tm)" -> laggende UI). Unter Xwayland ist NVIDIA hier
      # ohnehin der GLX-Provider, die App bekommt damit direkt
      # "vendor NVIDIA Corporation, RTX 4080/PCIe/SSE2" — GANZ OHNE
      # __NV_PRIME_*-Variablen.
      # WARNUNG (teuer gelernt, 2 Anlaeufe): Die klassischen PRIME-Offload-Vars
      # (__NV_PRIME_RENDER_OFFLOAD, __GLX_VENDOR_LIBRARY_NAME=nvidia,
      # __VK_LAYER_NV_optimus) hier NICHT setzen!
      #   - auf Wayland/EGL: GL-Kontext kommt nie hoch ("post_init: glcontext
      #     not ready" endlos -> leere 3D-View, Crash bei Preview-Wechsel)
      #   - auf X11: zwingt Mesa/zink-Umweg -> Fenster bleibt komplett blank
      #     und haengt (Log sieht dabei sogar gesund aus!)
      export GDK_BACKEND=x11
    '';

    extraPkgs = pkgs: with pkgs; [
      cacert
      glib
      glib-networking
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      webkitgtk_4_1
      # ADDED 2026-08-20: libsoup_3 explizit — das AppImage-Binary linkt
      # libsoup-3.0.so.0 direkt; wrapType2 legt nur explizit gelistete Pkgs in
      # den LD-Pfad, die transitive libsoup aus webkitgtk_4_1 reicht nicht.
      # (Symptom: "error while loading shared libraries: libsoup-3.0.so.0")
      libsoup_3
    ];

    # Desktop-Datei + Icon stecken im AppImage-Root (wrapType2 installiert nur
    # $out/bin). Exec=AppRun %F -> orca-studio %F.
    extraInstallCommands = let
      appimageContents = super.appimageTools.extract { inherit pname version src; };
    in ''
      install -Dm444 ${appimageContents}/com.orcaslicer.OrcaStudio.desktop \
        $out/share/applications/com.orcaslicer.OrcaStudio.desktop
      install -Dm444 ${appimageContents}/OrcaStudio.png \
        $out/share/icons/hicolor/192x192/apps/OrcaStudio.png
      substituteInPlace $out/share/applications/com.orcaslicer.OrcaStudio.desktop \
        --replace-fail 'Exec=AppRun %F' 'Exec=orca-studio %F'
    '';
  };
}
