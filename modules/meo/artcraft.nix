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
    version = "0.7.0";
    sha256 = "87ebce36bcdf6b31d16a9ca22ce29f9ad8db68185e4d98118800d1c2de78ac42";
    description = "Image editor (Photoshop reimplementation in Rust, PSD/PSB)";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
    version = "0.9.0";
    sha256 = "77eefa2c1ca7681e4b9aede638db314636da8d504aea107d48fb3367b6f61238";
    description = "Vector graphics editor (Illustrator reimplementation in Rust)";
  };

  designcraft = mkCraft {
    pname = "designcraft";
    version = "0.6.0";
    sha256 = "fb62e7e7a9adee2fd7f400b2ba26093b96a803470a7d8d476e39196f05c4c034";
    description = "Page layout and publishing (InDesign reimplementation in Rust)";
  };

  lightcraft = mkCraft {
    pname = "lightcraft";
    version = "0.6.0";
    sha256 = "577ef018dceec8d4980d2f9b20782ec37848158b8e6419cc90d31c2b580c1919";
    description = "Photo library and raw developer (Lightroom reimplementation in Rust)";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
    version = "0.6.0";
    sha256 = "c0b5a5d0f0e71176aa806c895f8ca513f2d505b70fef85b874bbe23c91232bc7";
    description = "Video editor (Premiere Pro reimplementation in Rust)";
  };

  effectcraft = mkCraft {
    pname = "effectcraft";
    version = "0.8.0";
    sha256 = "31221dab631fef3a38d140546ffc2a6955459b859877845a8282d9a97239b373";
    description = "Motion graphics and VFX (After Effects reimplementation in Rust)";
  };

  pdfcraft = mkCraft {
    pname = "pdfcraft";
    version = "0.6.0";
    # Seit v0.6.0 heisst auch das Asset pdfcraft (vorher printcraft).
    sha256 = "17314af5443f581f4516deaefdabc1e70f83199a61412a10deaf673adaef028c";
    description = "PDF workbench (Acrobat reimplementation in Rust)";
  };
}
