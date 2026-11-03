{...}: let
  # ADDED 2026-11-03: ArtCraft-Apps als Standardprogramme (beide Hosts).
  # Die MIME-Typen stammen aus den .desktop-Dateien der AppImages
  # (/run/current-system/sw/share/applications/ai.storyteller.*.desktop).
  # Wo sich mehrere Apps denselben Typ teilen, gilt: Pixelbilder ->
  # photocraft, Vektor -> vectorcraft, Raw/HEIC -> lightcraft, DXF ->
  # cadcraft, PDF -> pdfcraft. Bewusst NICHT an WordCraft: text/html,
  # text/markdown, text/x-tex (Browser bzw. Editor bleiben).
  # mimeDefaultApps in hosts/<host>/variables.nix darf dieselben Typen nicht
  # noch einmal setzen (Home-Manager meldet sonst einen Konflikt); dort nur
  # Browser & Co.
  app = name: "ai.storyteller.${name}.desktop";
  fuer = name: typen: builtins.listToAttrs (map (t: {
      name = t;
      value = app name;
    })
    typen);
in {
  xdg.mimeApps.defaultApplications =
    fuer "wordcraft" [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
      "application/vnd.ms-word.document.macroEnabled.12"
      "application/vnd.ms-word.template.macroEnabled.12"
      "application/msword"
      "application/msword-template"
      "application/vnd.oasis.opendocument.text"
      "application/rtf"
      "text/rtf"
    ]
    // fuer "gridcraft" [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
      "application/vnd.oasis.opendocument.spreadsheet"
      "text/csv"
      "text/tab-separated-values"
    ]
    // fuer "deckcraft" [
      "application/x-deckcraft"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/vnd.openxmlformats-officedocument.presentationml.template"
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
    ]
    // fuer "pdfcraft" [
      "application/pdf"
      "application/x-pdf"
    ]
    // fuer "photocraft" [
      "application/x-photocraft"
      "image/vnd.adobe.photoshop"
      "image/x-psd"
      "image/x-psb"
      "image/openraster"
      "application/x-krita"
      "image/x-paintnet"
      "image/png"
      "image/jpeg"
      "image/tiff"
      "image/webp"
      "image/gif"
      "image/bmp"
      "image/x-tga"
      "image/x-icon"
      "image/vnd.microsoft.icon"
      "image/x-portable-anymap"
      "image/x-portable-bitmap"
      "image/x-portable-graymap"
      "image/x-portable-pixmap"
      "image/x-exr"
      "image/vnd.radiance"
      "image/avif"
      "image/qoi"
    ]
    // fuer "vectorcraft" [
      "application/x-vectorcraft"
      "application/x-vectorcraft-template"
      "image/svg+xml"
      "image/svg+xml-compressed"
      "application/illustrator"
      "application/x-ai-template"
      "application/x-affinity"
      "image/x-eps"
      "image/emf"
      "image/wmf"
    ]
    // fuer "designcraft" [
      "application/x-designcraft"
      "application/vnd.adobe.indesign-idml-package"
    ]
    // fuer "lightcraft" [
      "image/heic"
      "image/heif"
      "image/x-adobe-dng"
      "image/x-sony-arw"
      "image/x-canon-cr2"
      "image/x-canon-cr3"
      "image/x-nikon-nef"
      "image/x-fuji-raf"
      "image/x-olympus-orf"
      "image/x-panasonic-rw2"
      "image/x-panasonic-rw"
      "image/x-pentax-pef"
    ]
    // fuer "filmcraft" [
      "application/x-filmcraft"
      "video/mp4"
      "video/x-m4v"
      "video/quicktime"
      "video/x-matroska"
      "video/webm"
      "video/vnd.avi"
      "video/x-msvideo"
      "application/mxf"
      "video/mp2t"
      "video/mpeg"
      "video/3gpp"
    ]
    // fuer "soundcraft" [
      "application/x-soundcraft-session"
      "audio/x-wav"
      "audio/wav"
      "audio/vnd.wave"
      "audio/x-aiff"
      "audio/aiff"
      "audio/flac"
      "audio/x-flac"
      "audio/mpeg"
      "audio/midi"
      "audio/x-midi"
    ]
    // fuer "cadcraft" [
      "image/vnd.dxf"
      "image/vnd.dwg"
      "application/x-dxf"
      "application/acad"
    ];
}
