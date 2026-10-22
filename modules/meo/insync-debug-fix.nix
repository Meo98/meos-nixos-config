# ADDED 2026-10-22: insync 3.9.11 baut am nixpkgs-Kanal-Kopf (Stand
# 2026-10-20) nicht: der neue autoPatchelfHook versucht, auch die mitgelieferte
# Debug-Symboldatei PySide2/Qt/libexec/QtWebEngineProcess.debug zu patchen,
# patchelf --set-interpreter scheitert daran -> Build-Abbruch, blockierte `fu`.
#
# Workaround: *.debug-Dateien vor der Fixup-Phase loeschen (insync braucht
# sie nicht). Das innere insync-pkg ist im nixpkgs-Rezept ein let-Binding und
# nicht per overrideAttrs erreichbar; einziger Hebel ist das stdenvNoCC-
# Argument, das NUR insync-pkg benutzt.
# ENTFERNEN, sobald nixpkgs insync repariert hat. Test: Overlay-Import in
# hosts/*/host-packages.nix auskommentieren und `nh os build` laufen lassen.
final: prev: {
  insync = prev.insync.override {
    stdenvNoCC =
      prev.stdenvNoCC
      // {
        mkDerivation = args:
          prev.stdenvNoCC.mkDerivation (args
            // {
              preFixup =
                (args.preFixup or "")
                + ''
                  find $out -type f -name '*.debug' -delete
                '';
            });
      };
  };
}
