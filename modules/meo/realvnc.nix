# RealVNC Connect Viewer (8.5.0) — Overlay, ADDED 2026-10-12
#
# WARUM EIGENE DERIVATION statt nixpkgs-Paket:
#   nixpkgs `realvnc-vnc-viewer` (7.15.1) baut NICHT mehr — RealVNC hat die
#   Datei vom Downloadserver geloescht (downloads.realvnc.com -> HTTP 404) und
#   die aktuellen Downloads hinter Cloudflare gelegt (www.realvnc.com -> 403).
#   Nix/curl kommen da nicht durch, ein echter Browser schon.
#
# WARUM NOETIG: Die Technorama/SSC-VNC-Server sprechen RealVNCs proprietaere
#   Verschluesselung (RFB 5.0, RA2/RA2ne). libvncclient — also Remmina UND
#   TigerVNC — kann die NICHT (schwarzes Bild). Nur RealVNCs eigener Viewer.
#
# 8.5.0 ist eine Flutter-App ("RealVNC Connect Viewer"), komplett andere
#   Struktur als 7.x: Binary heisst `rvncconnect`, Libs liegen daneben in lib/.
#
# requireFile: Das rpm ist NICHT automatisch ladbar (Cloudflare). Es muss einmal
#   manuell per Browser geladen und in den Store gelegt werden:
#     1) https://www.realvnc.com/en/connect/download/viewer/linux/  -> RPM x64
#     2) nix-store --add-fixed sha256 ~/Downloads/RealVNC-Connect-Viewer-8.5.0-Linux-x64.rpm
#   Beim Versionsbump: version + hash unten anpassen, Schritte 1-2 wiederholen.

final: prev:

let
  version = "8.5.0";
in
{
  realvnc-vnc-viewer = prev.stdenv.mkDerivation {
    pname = "realvnc-vnc-viewer";
    inherit version;

    src = prev.requireFile {
      name = "RealVNC-Connect-Viewer-${version}-Linux-x64.rpm";
      hash = "sha256-x/NG9ivYUbtrFxksglCLF+lGA2OO2VdEN1qPsvum7tQ=";
      url = "https://www.realvnc.com/en/connect/download/viewer/linux/";
      message = ''
        RealVNC Connect Viewer ${version} laesst sich wegen Cloudflare nicht
        automatisch laden. Bitte einmalig manuell holen:

          1) Im Browser oeffnen:
             https://www.realvnc.com/en/connect/download/viewer/linux/
             -> "VNC Viewer" als RPM (x64) herunterladen
          2) In den Nix-Store legen:
             nix-store --add-fixed sha256 \
               ~/Downloads/RealVNC-Connect-Viewer-${version}-Linux-x64.rpm

        Danach erneut bauen.
      '';
    };

    nativeBuildInputs = [
      prev.autoPatchelfHook
      prev.rpmextract
    ];

    buildInputs = [
      prev.glib            # libglib-2.0, libgio-2.0, libgobject-2.0
      prev.gtk3            # libgtk-3, libgdk-3
      prev.xorg.libX11
      prev.xorg.libXext
      prev.stdenv.cc.cc.lib # libgcc_s, libstdc++
    ];

    unpackPhase = ''
      runHook preUnpack
      rpmextract $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      # Flutter-App samt gebundelten Libs (lib/libflutter_linux_gtk.so,
      # lib/libhex_window_manager_plugin.so, lib/libapp.so) uebernehmen.
      mkdir -p $out/lib
      cp -r usr/lib/rvncconnect $out/lib/rvncconnect

      # Icon
      mkdir -p $out/share/icons/hicolor/scalable/apps
      cp usr/share/icons/hicolor/scalable/apps/com.realvnc.rvncconnect.svg \
         $out/share/icons/hicolor/scalable/apps/

      # Desktop-Eintraege reparieren. RealVNC liefert sie fehlerhaft aus, und
      # strikte Parser (quickshell/DMS-Spotlight, im Gegensatz zum laxen GTK)
      # werfen sie dann still raus -> Eintrag fehlt im App-Launcher:
      #   - CRLF statt LF (Windows-Zeilenenden)          -> sed 's/\r$//'
      #   - Version=8.5.0 ist ungueltig (meint Spec-Ver)  -> 1.5
      #   - Categories=Application;... (veralteter Wert)   -> Network;RemoteAccess;
      # Ausserdem absolute /usr/lib-Pfade auf $out, Icon auf den Namen reduzieren.
      mkdir -p $out/share/applications
      for d in usr/share/applications/*.desktop; do
        sed -e 's/\r$//' \
            -e "s#/usr/lib/rvncconnect/rvncconnect#$out/lib/rvncconnect/rvncconnect#g" \
            -e "s#^Icon=.*#Icon=com.realvnc.rvncconnect#" \
            -e "s#^Version=8\.5\.0#Version=1.5#" \
            -e "s#^Categories=.*#Categories=Network;RemoteAccess;#" \
            "$d" > "$out/share/applications/$(basename "$d")"
      done

      # Startbefehle: offizieller Name + `vncviewer` als vertrauter Alias.
      mkdir -p $out/bin
      ln -s $out/lib/rvncconnect/rvncconnect $out/bin/rvncconnect
      ln -s $out/lib/rvncconnect/rvncconnect $out/bin/vncviewer

      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "RealVNC Connect Viewer (proprietaerer Client, spricht RA2/RA2ne)";
      homepage = "https://www.realvnc.com/en/connect/download/viewer/";
      license = {
        fullName = "VNC Connect End User License Agreement";
        url = "https://static.realvnc.com/media/documents/LICENSE-4.0a_en.pdf";
        free = false;
      };
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "vncviewer";
    };
  };
}
