# ADDED 2026-10-22: khal 0.14.1 baut am nixpkgs-Kanal-Kopf (Stand 2026-10-20)
# nicht: der sphinx-"man"-Builder erzeugt nichts, das Paket deklariert aber
# einen `man`-Output -> "failed to produce output path for output 'man'".
# khal kommt nicht aus unserer Config, sondern als Abhaengigkeit der
# DMS-Bar (Kalender-Termine) in home.packages, blockierte damit `fu`.
#
# Workaround: nur die HTML-Doku bauen, `man`-Output weglassen.
# ENTFERNEN, sobald nixpkgs khal repariert hat. Test: Overlay-Import in
# hosts/*/host-packages.nix auskommentieren und `nh os build` laufen lassen.
final: prev: {
  khal = prev.khal.overridePythonAttrs (old: {
    outputs = ["out" "doc"];
    sphinxBuilders = ["html"];
  });
}
