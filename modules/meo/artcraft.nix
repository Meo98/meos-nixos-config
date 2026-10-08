self: super: let
  # ADDED 2026-10-08: ArtCraft Suite (github.com/storytold, Apache-2.0) —
  # native Linux-Alternative zu Affinity/Adobe, in Rust geschrieben, ohne
  # Wine. Zuordnung zu Affinity:
  #   photocraft  ≙ Affinity Photo     (Photoshop-Nachbau, PSD/PSB nativ)
  #   vectorcraft ≙ Affinity Designer  (Illustrator-Nachbau)
  #   designcraft ≙ Affinity Publisher (InDesign-Nachbau)
  # Zusaetzlich: lightcraft (Lightroom), filmcraft (Premiere),
  # effectcraft (After Effects), pdfcraft (Acrobat; Asset heisst bei v0.2.1
  # noch "printcraft", Repo wurde gerade umbenannt).
  #
  # STATUS: "early alpha" laut Upstream-Badge (Stand 2026-10-08). Erwartbar:
  # fehlende Werkzeuge, Abstuerze, haeufige Releases. Dafuer startet es in
  # <2 s nativ unter niri/Wayland (getestet: PhotoCraft 0.3.0 via appimage-run).
  #
  # Die AppImages buendeln KEINE Libs (kein usr/lib), nur das Rust-Binary —
  # wrapType2 liefert libc/Mesa/Vulkan/Wayland aus der FHS-Sandbox. Dieselbe
  # Basis wie appimage-run, deshalb keine extraPkgs noetig.
  #
  # Bei Version-Bump pro App:
  #   gh release view --repo storytold/<app>
  #   curl -sL https://github.com/storytold/<app>/releases/download/v<ver>/SHA256SUMS.txt \
  #     | grep linux-x86_64.AppImage
  # und den Hex-Hash unten eintragen (sha256 = "<hex>" wird von fetchurl
  # direkt akzeptiert).
  mkCraft = {
    pname,
    version,
    sha256,
    description,
    repo ? pname,
    asset ? pname,
  }:
    super.appimageTools.wrapType2 rec {
      inherit pname version;

      src = super.fetchurl {
        url = "https://github.com/storytold/${repo}/releases/download/v${version}/${asset}-${version}-linux-x86_64.AppImage";
        inherit sha256;
      };

      # Desktop-Datei + Icon liegen im AppImage-Root (wrapType2 installiert nur
      # $out/bin/${pname}). Dateinamen variieren (ai.storyteller.<name>.*,
      # bei pdfcraft noch ...printcraft...), daher per Glob. Exec= zeigt auf
      # den Upstream-Binary-Namen und wird auf unseren Wrapper umgebogen.
      extraInstallCommands = let
        contents = super.appimageTools.extract {inherit pname version src;};
      in ''
        for f in ${contents}/*.desktop; do
          install -Dm444 "$f" "$out/share/applications/$(basename "$f")"
          sed -i 's|^Exec=.*|Exec=${pname} %F|; s|^TryExec=.*|TryExec=${pname}|' \
            "$out/share/applications/$(basename "$f")"
        done
        for f in ${contents}/*.png; do
          install -Dm444 "$f" "$out/share/pixmaps/$(basename "$f")"
        done
      '';

      meta = with super.lib; {
        inherit description;
        homepage = "https://github.com/storytold/${repo}";
        license = licenses.asl20;
        platforms = ["x86_64-linux"];
        mainProgram = pname;
      };
    };
in {
  photocraft = mkCraft {
    pname = "photocraft";
    version = "0.3.0";
    sha256 = "29e3011f49a52ea25c8fe404258a6c5fadb02094dbb40a884d69e6ba808e6136";
    description = "Image editor (Photoshop reimplementation in Rust, PSD/PSB)";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
    version = "0.4.0";
    sha256 = "ff473f200b0103602d4e83e00bb565284d2ab03445a9ad2f76bf8ffdb302d850";
    description = "Vector graphics editor (Illustrator reimplementation in Rust)";
  };

  designcraft = mkCraft {
    pname = "designcraft";
    version = "0.2.1";
    sha256 = "78141184d4ebc0183fe9c2609611d2a33e67668738548cc022b6778398ec8340";
    description = "Page layout and publishing (InDesign reimplementation in Rust)";
  };

  lightcraft = mkCraft {
    pname = "lightcraft";
    version = "0.2.1";
    sha256 = "c2f39adaa8a6536d5014a7ba102ff785e1a323a02e089d01db1f85378dc0fc53";
    description = "Photo library and raw developer (Lightroom reimplementation in Rust)";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
    version = "0.2.1";
    sha256 = "7891c9b24c8e165a54906f8ee6a6973e051dd3c2cc1fa2729a78269fec481188";
    description = "Video editor (Premiere Pro reimplementation in Rust)";
  };

  effectcraft = mkCraft {
    pname = "effectcraft";
    version = "0.4.0";
    sha256 = "994c374c54e920a12ff20fbe443199acaf49c03b30380e7a5c17b60208743d71";
    description = "Motion graphics and VFX (After Effects reimplementation in Rust)";
  };

  pdfcraft = mkCraft {
    pname = "pdfcraft";
    version = "0.2.1";
    # Repo heisst pdfcraft, das v0.2.1-Asset (und die Desktop-Datei darin)
    # noch printcraft. Beim naechsten Bump pruefen, ob asset entfallen kann.
    asset = "printcraft";
    sha256 = "401735c646bc5884cf1ff799d46913bce7dc3d29d06ff5a2902697e65465f584";
    description = "PDF workbench (Acrobat reimplementation in Rust)";
  };
}
