{ pkgs, ... }:

# Datei-Konvertierung: Dokumente -> PDF (und zwischen Office-Formaten).
#
# Ergaenzt nur, was noch fehlt. Bereits vorhanden und daher hier NICHT
# nochmal deklariert:
#   pandoc, ffmpeg, imagemagick -> modules/upstream/core/packages.nix
#   poppler-utils (pdfinfo/pdftotext) -> modules/meo/pdf-tools.nix
{
  home.packages = with pkgs; [
    # PDF-Engine fuer pandoc. Ohne sie kann pandoc KEIN PDF schreiben — es
    # delegiert an eine externe Engine, und ohne LaTeX/weasyprint/typst
    # bricht `pandoc -o datei.pdf` schlicht ab.
    #
    #   pandoc datei.md --pdf-engine=weasyprint -o datei.pdf
    #
    # weasyprint statt texlive gewaehlt: rendert ueber CSS (also gestaltbar
    # mit @page, Seitenzahlen, Kopfzeilen) und kostet ~50 MB statt ~5 GB.
    # Der Umweg ueber `google-chrome --headless --print-to-pdf` entfaellt damit.
    # Attribut liegt unter python3Packages, NICHT auf Top-Level —
    # `weasyprint` allein ergibt "undefined variable".
    python3Packages.weasyprint

    # Office-Formate im Batch: docx/xlsx/pptx/odt -> PDF, ohne GUI-Start.
    #   soffice --headless --convert-to pdf --outdir . datei.docx
    # Deckt genau die Formate ab, bei denen pandoc die Formatierung verliert
    # (komplexe Layouts, eingebettete Tabellen aus Excel).
    libreoffice
  ];
}
