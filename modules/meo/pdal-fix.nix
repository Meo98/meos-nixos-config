# TEMPORÄRES Overlay 2026-07-16: pdal 2.9.3 -> 2.10.0
#
# Warum: nixpkgs (Stand 20260715, auch nixos-unstable) kombiniert pdal 2.9.3
# mit GDAL 3.13.1 + gcc 15. GDAL 3.13 gibt GetMetadata() als CSLConstList
# (const char* const*) zurück, pdal 2.9.3 weist das noch char** zu ->
# harter Compile-Fehler in Raster.cpp:704. Upstream-Fix ist in pdal 2.10.0
# (PDAL/PDAL PR #4929). Blockierte die Kette pdal -> vtk -> freecad und
# damit den gesamten Rebuild.
#
# ENTFERNEN sobald nixpkgs pdal >= 2.10.0 hat:
#   nix eval --raw github:NixOS/nixpkgs/nixos-unstable#pdal.version
# Dann dieses File löschen + Einbindung in hosts/*/host-packages.nix raus.
#
# Hash geholt via: nix flake prefetch "github:PDAL/PDAL/2.10.0" --json
self: super: {
  pdal = super.pdal.overrideAttrs (old: rec {
    version = "2.10.0";
    src = super.fetchFromGitHub {
      owner = "PDAL";
      repo = "PDAL";
      rev = version;
      hash = "sha256-uqWawto3EJJaFhmhQn9eg+4s7NuhmVO5YXC6igkCeU0=";
    };
    # 2.9.3 hatte in nixpkgs keine Patches (verifiziert: patches == []),
    # explizit leer halten, falls sich das upstream ändert und nicht applied.
    patches = [ ];
    # 2.10.0 bringt pdal_io_copc_remote_reader_test mit: laedt Testdaten uebers
    # Netz -> in der netzlosen Nix-Sandbox zwangslaeufig rot (140/141 gruen,
    # lokal verifiziert 2026-07-16). Tests daher aus.
    doCheck = false;
  });
}
