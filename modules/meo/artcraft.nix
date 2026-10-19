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
  # ADDED 2026-10-15: Office-/Audio-/CAD-Teil der Suite:
  #   wordcraft  ≙ Word, gridcraft ≙ Excel, deckcraft ≙ PowerPoint,
  #   soundcraft ≙ Pro Tools (DAW), cadcraft ≙ AutoCAD (2D-Zeichnen).
  # Gleiche Release-Struktur (AppImage + SHA256SUMS.txt), gleicher mkCraft.
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
        # ADDED 2026-10-15: Jedes AppImage bringt unter usr/bin auch `<app>-cli`
        # mit (Headless-Engine, Skripte, MCP-Server fuer Claude Code:
        # `<app>-cli mcp`, bzw. `--connect 7979` gegen die mit
        # `<app> --control 7979` gestartete GUI). Das CLI braucht keine
        # FHS-Sandbox: reines Rust-Binary, laeuft dank nix-ld direkt.
        if [ -e "${contents}/usr/bin/${pname}-cli" ]; then
          ln -s "${contents}/usr/bin/${pname}-cli" "$out/bin/${pname}-cli"
        fi
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
    version = "0.10.0";
    sha256 = "cd1a33c979e8a5da94ded81d7648e779cb8069b77e4aca743c8d177ca5270d77";
    description = "Image editor (Photoshop reimplementation in Rust, PSD/PSB)";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
    version = "0.13.1";
    sha256 = "95457bb9b48bc6344124c2bf32a106006548aa594b1b8d1d8ca47d52a30e577e";
    description = "Vector graphics editor (Illustrator reimplementation in Rust)";
  };

  designcraft = mkCraft {
    pname = "designcraft";
    # 0.9.0 (2026-10-18): Create Guides nimmt die Seite in Ansicht und hat
    # "Apply to: This page / Spread" (vorher immer Seite 1, Workaround war das
    # spread-Feld). Parent-Page-Guides werden auf Body-Seiten noch NICHT
    # gezeichnet (inherited_guides fehlt im Release).
    version = "0.9.0";
    sha256 = "e5ab60399b923271235940118918d6f0c460a3082a090b0f6fe4d9d0490da9b5";
    description = "Page layout and publishing (InDesign reimplementation in Rust)";
  };

  lightcraft = mkCraft {
    pname = "lightcraft";
    version = "0.9.1";
    sha256 = "bd002851a9524349c9d8922ae2b85c98c257de16480d3b7f885801a3b64b6d18";
    description = "Photo library and raw developer (Lightroom reimplementation in Rust)";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
    version = "0.9.0";
    sha256 = "784e4cdbd8982f17b4ec81caf5367fd308d70a123a7aa74bccd7420214c0c447";
    description = "Video editor (Premiere Pro reimplementation in Rust)";
  };

  effectcraft = mkCraft {
    pname = "effectcraft";
    version = "0.11.1";
    sha256 = "231e60f367334d7e85891fe653c4a434aa093c21313e1ecc8fe1459b6fd58379";
    description = "Motion graphics and VFX (After Effects reimplementation in Rust)";
  };

  pdfcraft = mkCraft {
    pname = "pdfcraft";
    version = "0.9.0";
    # Seit v0.6.0 heisst auch das Asset pdfcraft (vorher printcraft).
    sha256 = "f8568c87906d968461052f0b57097c0b84b70b37bf649c9b504d8c1eb7ad0cfa";
    description = "PDF workbench (Acrobat reimplementation in Rust)";
  };

  wordcraft = mkCraft {
    pname = "wordcraft";
    version = "0.8.0";
    sha256 = "7df7b3a50172ba0ede85a2c4b83c360af92b1c3767c8b30c3963ebf05d36ab9c";
    description = "Word processor (Microsoft Word reimplementation in Rust, DOCX)";
  };

  gridcraft = mkCraft {
    pname = "gridcraft";
    version = "0.8.0";
    sha256 = "942096a29a534aa2503e9e7aa1816e952f7250e73d55f8f32afd077547617f77";
    description = "Spreadsheet (Microsoft Excel reimplementation in Rust, XLSX)";
  };

  deckcraft = mkCraft {
    pname = "deckcraft";
    version = "0.8.0";
    sha256 = "5c24e0c3d52c710219fb6b897cbf2e856e0f6dd4dc79b7a2cefc1d2d55134ed0";
    description = "Presentations (Microsoft PowerPoint reimplementation in Rust, PPTX)";
  };

  soundcraft = mkCraft {
    pname = "soundcraft";
    version = "0.8.0";
    sha256 = "9c38f8d1a5c818f673a17f68a952ea8972cea4ab4720590bdb7e393504866768";
    description = "Digital audio workstation (Avid Pro Tools reimplementation in Rust)";
  };

  cadcraft = mkCraft {
    pname = "cadcraft";
    version = "0.8.0";
    sha256 = "24f77e372bf07233f72672458bc69135d54bc9f6bb6379ed737870a7c1152bd2";
    description = "2D CAD and drafting (AutoCAD reimplementation in Rust, DXF/DWG)";
  };
}
