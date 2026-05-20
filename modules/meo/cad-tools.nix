{ pkgs, ... }:

# CAD / Laser / 3D-Druck Tooling für PCB-Gehäuse und Laser-Abdeckungen.
# Workflow: KiCad (PCB-Quelle) -> DXF/STEP-Export -> hier weiterverarbeiten.
{
  home.packages = with pkgs; [
    # Code-basiertes parametrisches CAD. Cases als .scad-Datei (text, git-bar).
    # F5 = Vorschau, F6 = Render, dann STL-Export für den 3D-Drucker.
    openscad

    # GUI parametrisches 3D-CAD. Für komplexere Gehäuse + die "KiCad StepUp"
    # Workbench (über FreeCAD Addon-Manager nachinstallieren), die .kicad_pcb
    # direkt importiert und passgenaue Cases ermöglicht.
    freecad

    # Vektor-Editor für 2D-Laser (Plexiglas-Abdeckung). Importiert SVG/PDF/DXF,
    # exportiert DXF für Laser-Cutter. Auch zum Verfeinern von KiCad-DXF-Exports.
    inkscape

    # PrusaSlicer: STL -> G-Code für den 3D-Drucker (Slicing). Falls dein
    # Drucker einen anderen Slicer braucht (Bambu/Cura), sag Bescheid.
    prusa-slicer
  ];
}
