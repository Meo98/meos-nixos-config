# Overlay: master-pdf-editor 5.9.98 -> 5.9.99
#
# code-industry.net hostet immer nur die JEWEILS neueste Version. Als der
# Hersteller auf 5.9.99 wechselte, verschwand der 5.9.98-Tarball -> Download
# 404 -> meo-work-Build (und CI) brachen ab:
#   master-pdf-editor-5.9.98-...-qt_include.tar.gz  →  HTTP 404
#
# Fix = Bump auf 5.9.99 (am 2026-08-22 verifiziert: URL 200 OK, Hash geprüft).
# nixpkgs' eigene Definition nutzt finalAttrs.version in der URL, daher genügt
# overrideAttrs mit version + neuem src.
#
# Bei erneutem 404 nach dem nächsten Hersteller-Release:
#   1) neue Version:  curl -s https://code-industry.net/downloads/ | grep -i 'Version'
#   2) neuer Hash:    nix store prefetch-file --hash-type sha256 \
#        "https://code-industry.net/public/master-pdf-editor-<VER>-qt5.x86_64-qt_include.tar.gz"
#   3) version + hash hier eintragen.
# Entfällt, sobald nixpkgs selbst auf >= 5.9.99 bumpt.
final: prev: {
  masterpdfeditor = prev.masterpdfeditor.overrideAttrs (old: rec {
    version = "5.9.99";
    src = prev.fetchurl {
      url = "https://code-industry.net/public/master-pdf-editor-${version}-qt5.x86_64-qt_include.tar.gz";
      hash = "sha256-ksVuJyuImstESVwHUmOUv6aERosg6g5bSsRvPSf5EVM=";
    };
  });
}
