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
  # VERSIONEN: stehen NICHT hier, sondern in artcraft-versions.json
  # (version + sha256 pro App). Gepflegt vom Skript `artcraft-update`
  # (modules/meo/scripts/artcraft-update.nix): holt pro App das neueste
  # GitHub-Release + Hash aus dessen SHA256SUMS.txt. Laeuft automatisch in
  # `fu` und im naechtlichen update-prewarm, d.h. ArtCraft folgt immer Latest,
  # aber nur, wenn das System damit auch baut (fu rollt sonst zurueck).
  # Von Hand: `artcraft-update` (ohne Argument -> ~/nixos-config).
  versions = builtins.fromJSON (builtins.readFile ./artcraft-versions.json);

  mkCraft = {
    pname,
    version ? versions.${pname}.version,
    sha256 ? versions.${pname}.sha256,
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
    description = "Image editor (Photoshop reimplementation in Rust, PSD/PSB)";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
    description = "Vector graphics editor (Illustrator reimplementation in Rust)";
  };

  designcraft = mkCraft {
    pname = "designcraft";
    # 0.9.0 (2026-10-18): Create Guides nimmt die Seite in Ansicht und hat
    # "Apply to: This page / Spread" (vorher immer Seite 1, Workaround war das
    # spread-Feld). Parent-Page-Guides werden auf Body-Seiten noch NICHT
    # gezeichnet (inherited_guides fehlt im Release).
    description = "Page layout and publishing (InDesign reimplementation in Rust)";
  };

  lightcraft = mkCraft {
    pname = "lightcraft";
    description = "Photo library and raw developer (Lightroom reimplementation in Rust)";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
    description = "Video editor (Premiere Pro reimplementation in Rust)";
  };

  effectcraft = mkCraft {
    pname = "effectcraft";
    description = "Motion graphics and VFX (After Effects reimplementation in Rust)";
  };

  pdfcraft = mkCraft {
    pname = "pdfcraft";
    # Seit v0.6.0 heisst auch das Asset pdfcraft (vorher printcraft).
    description = "PDF workbench (Acrobat reimplementation in Rust)";
  };

  wordcraft = mkCraft {
    pname = "wordcraft";
    description = "Word processor (Microsoft Word reimplementation in Rust, DOCX)";
  };

  gridcraft = mkCraft {
    pname = "gridcraft";
    description = "Spreadsheet (Microsoft Excel reimplementation in Rust, XLSX)";
  };

  deckcraft = mkCraft {
    pname = "deckcraft";
    description = "Presentations (Microsoft PowerPoint reimplementation in Rust, PPTX)";
  };

  soundcraft = mkCraft {
    pname = "soundcraft";
    description = "Digital audio workstation (Avid Pro Tools reimplementation in Rust)";
  };

  cadcraft = mkCraft {
    pname = "cadcraft";
    description = "2D CAD and drafting (AutoCAD reimplementation in Rust, DXF/DWG)";
  };
}
