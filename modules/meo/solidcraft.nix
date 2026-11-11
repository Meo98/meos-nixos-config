self: super: {
  # ADDED 2026-11-11: SolidCraft (github.com/tangency-labs/solidcraft,
  # Apache-2.0) — parametrisches 3D-CAD in Rust (SolidWorks/Fusion-Richtung),
  # Desktop + Web + MCP fuer Automation. NICHT Teil der ArtCraft Suite
  # (anderer Hersteller), daher eigenes Overlay statt mkCraft.
  # Nicht in nixpkgs (Stand 2026-11-11).
  #
  # Version bewusst von Hand: Upstream veroeffentlicht viele Release
  # Candidates (z.B. 0.40.0-rc.4); hier nur stabile Releases
  # (`gh api repos/tangency-labs/solidcraft/releases/latest`).
  # Bump: version aendern, Hash aus dem SHA256SUMS.txt des Releases
  # (Zeile ...-linux-x86_64.AppImage) uebernehmen.
  solidcraft = super.appimageTools.wrapType2 rec {
    pname = "solidcraft";
    version = "0.30.1";

    src = super.fetchurl {
      url = "https://github.com/tangency-labs/solidcraft/releases/download/v${version}/solidcraft-${version}-linux-x86_64.AppImage";
      sha256 = "1ce0d61afd38200f0c1627931a0485f03b83e0a88b1c74c75e1a1501e938835d";
    };

    # Desktop-Datei + Icon aus dem AppImage-Root uebernehmen (wrapType2
    # installiert sonst nur $out/bin/solidcraft) und Exec= auf den Wrapper
    # umbiegen. Ein mitgeliefertes CLI wird verlinkt, falls vorhanden.
    extraInstallCommands = let
      contents = super.appimageTools.extract {inherit pname version src;};
    in ''
      for f in ${contents}/*.desktop; do
        install -Dm444 "$f" "$out/share/applications/$(basename "$f")"
        sed -i 's|^Exec=.*|Exec=${pname} %F|; s|^TryExec=.*|TryExec=${pname}|' \
          "$out/share/applications/$(basename "$f")"
      done
      for f in ${contents}/*.png ${contents}/*.svg; do
        [ -e "$f" ] && install -Dm444 "$f" "$out/share/pixmaps/$(basename "$f")"
      done
      if [ -e "${contents}/usr/bin/${pname}-cli" ]; then
        ln -s "${contents}/usr/bin/${pname}-cli" "$out/bin/${pname}-cli"
      fi
    '';

    meta = with super.lib; {
      description = "Parametric 3D CAD in pure Rust (desktop, web, MCP automation)";
      homepage = "https://solidcraft.io";
      license = licenses.asl20;
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  };
}
