# RealVNC Viewer 7.13.1 — Overlay, ADDED 2026-10-12, auf 7.x zurueck 2026-10-19
#
# WARUM NOETIG: Die Technorama/SSC-VNC-Server sprechen RealVNCs proprietaere
#   Verschluesselung (RFB 5.0, RA2/RA2ne). libvncclient — also Remmina UND
#   TigerVNC — kann die NICHT (schwarzes Bild). Nur RealVNCs eigener Viewer.
#
# WARUM 7.x UND NICHT 8.x: Der "RealVNC Connect Viewer" 8.x (Flutter-App) laesst
#   auch Direktverbindungen (IP/Hostname) nur noch mit bezahltem Plan zu
#   ("Your trial has expired"). 7.x darf laut EULA ohne Konto direkt verbinden
#   ("Use RealVNC Viewer without signing in"). Ausserdem stuerzte 8.5.0 beim
#   "Sign in" ab (dlopen libproxy.so.1 fehlt, hart kodiertes /usr/bin/xdg-mime).
#
# WARUM OVERLAY statt nixpkgs-Paket: nixpkgs `realvnc-vnc-viewer` (7.15.1) baut
#   nicht mehr — RealVNC hat alle 7.x-Dateien vom Downloadserver geloescht
#   (downloads.realvnc.com -> HTTP 404). Das 7.13.1-RPM gibt es noch im
#   Internet Archive. Das Overlay nimmt das nixpkgs-Rezept (linux.nix) und
#   tauscht nur version + src.
#
# requireFile: Datei einmalig von Hand in den Store legen:
#     1) curl -L -o VNC-Viewer-7.13.1-Linux-x64.rpm \
#          'https://web.archive.org/web/20250817145326id_/https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.13.1-Linux-x64.rpm'
#     2) nix-store --add-fixed sha256 VNC-Viewer-7.13.1-Linux-x64.rpm
#   sha256 (hex): 7212d81893f27b01def9bd2c1acece6ba27c138ef878b97bd04ae476727bfa32

final: prev:

let
  version = "7.13.1";
in
{
  realvnc-vnc-viewer = prev.realvnc-vnc-viewer.overrideAttrs (old: {
    inherit version;

    src = prev.requireFile {
      name = "VNC-Viewer-${version}-Linux-x64.rpm";
      hash = "sha256-chLYGJPyewHe+b0sGs7Oa6J8E474eLl70ErkdnJ7+jI=";
      url = "https://web.archive.org/web/20250817145326id_/https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-${version}-Linux-x64.rpm";
      message = ''
        RealVNC Viewer ${version} ist upstream geloescht. Einmalig aus dem
        Internet Archive holen und in den Store legen:

          curl -L -o VNC-Viewer-${version}-Linux-x64.rpm \
            'https://web.archive.org/web/20250817145326id_/https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-${version}-Linux-x64.rpm'
          nix-store --add-fixed sha256 VNC-Viewer-${version}-Linux-x64.rpm

        Danach erneut bauen.
      '';
    };
  });
}
