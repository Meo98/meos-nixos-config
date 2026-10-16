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
    version = "0.9.0";
    sha256 = "483a9a79200e0c0864bb54cf3faa6a55e2b79c1433dacfcb153d3862e78f32bc";
    description = "Image editor (Photoshop reimplementation in Rust, PSD/PSB)";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
    version = "0.11.0";
    sha256 = "0ab5126f9b2f9591bc27a10e20ea1b2f239384b1a16fec88288ed3de6dbf831c";
    description = "Vector graphics editor (Illustrator reimplementation in Rust)";
  };

  designcraft = mkCraft {
    pname = "designcraft";
    # 0.8.0 (2026-10-14): strikter spread-Check (PR #662), Parent-Page-Items
    # nach Seitenindex (PR #523). Der Fix "Create Guides auf der Seite in
    # Ansicht statt immer Seite 1" (Commit 524166f5) liegt nur auf main und
    # kommt erst mit dem naechsten Release; Workaround: im Dialog `spread`
    # = Spread-Index der Zielseite eintragen (Seite 2 -> 1).
    version = "0.8.0";
    sha256 = "88d57710f56c9fb7d8e33e046061eff839117971b402a4103c4b332b5ca3b5df";
    description = "Page layout and publishing (InDesign reimplementation in Rust)";
  };

  lightcraft = mkCraft {
    pname = "lightcraft";
    version = "0.8.0";
    sha256 = "81d54b09e60b448c05517f1dea3422bea5998692a8a1a84060466385b9dfd9c3";
    description = "Photo library and raw developer (Lightroom reimplementation in Rust)";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
    version = "0.8.0";
    sha256 = "41955e97c8932435f2b6bb8245783c668786b33d2b7df962bd097641da68211e";
    description = "Video editor (Premiere Pro reimplementation in Rust)";
  };

  effectcraft = mkCraft {
    pname = "effectcraft";
    version = "0.10.0";
    sha256 = "d0e4016f6e5915bf847465fcfa4053a1607e0afa16b35fed156a78c75e88b650";
    description = "Motion graphics and VFX (After Effects reimplementation in Rust)";
  };

  pdfcraft = mkCraft {
    pname = "pdfcraft";
    version = "0.8.0";
    # Seit v0.6.0 heisst auch das Asset pdfcraft (vorher printcraft).
    sha256 = "6b89397ec10ad505e732f18982b6ad171aab085d938ca0c3034a00d4199e38f7";
    description = "PDF workbench (Acrobat reimplementation in Rust)";
  };

  wordcraft = mkCraft {
    pname = "wordcraft";
    version = "0.7.0";
    sha256 = "7dc86ff3025f185be39bf19822af24f2c504ddead3f52ed99c3d6960bce58d4d";
    description = "Word processor (Microsoft Word reimplementation in Rust, DOCX)";
  };

  gridcraft = mkCraft {
    pname = "gridcraft";
    version = "0.7.0";
    sha256 = "2daace8be3719afee727d2e353aa4bd0ac22798c312c92c2c6d5e42f27f70812";
    description = "Spreadsheet (Microsoft Excel reimplementation in Rust, XLSX)";
  };

  deckcraft = mkCraft {
    pname = "deckcraft";
    version = "0.7.0";
    sha256 = "535afd1e7f6d389ecfe78f4a702b5a36719217c4cec556ae5d7f0fd775ae5584";
    description = "Presentations (Microsoft PowerPoint reimplementation in Rust, PPTX)";
  };

  soundcraft = mkCraft {
    pname = "soundcraft";
    version = "0.7.0";
    sha256 = "80f2fecd132b9a9c3ac2391664b0a0214169c8cc0e27be917a3704553a914d81";
    description = "Digital audio workstation (Avid Pro Tools reimplementation in Rust)";
  };

  cadcraft = mkCraft {
    pname = "cadcraft";
    version = "0.7.0";
    sha256 = "b2aa2807c886e1bae7b0064f47688a62ed6fe1fa05f05b352e362cdc698f0b77";
    description = "2D CAD and drafting (AutoCAD reimplementation in Rust, DXF/DWG)";
  };
}
