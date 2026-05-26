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

    # (Inkscape entfernt — bei Bedarf für 2D-Laser/SVG->DXF wieder hinzufügen.)

    # PrusaSlicer: STL -> G-Code für den 3D-Drucker (Slicing). Falls dein
    # Drucker einen anderen Slicer braucht (Bambu/Cura), sag Bescheid.
    prusa-slicer

    # Python mit OpenCascade-Bindings für code-basierte parametrische CAD.
    # pythonocc-core ist die Library auf der CadQuery basiert — gleicher
    # B-Rep-Kernel wie FreeCAD. Kann STEP direkt lesen, echte Fillets/
    # Chamfers, schnelle Boolean-Ops auf B-Rep (statt langsam auf Mesh).
    # Workflow: case_v3.py → STEP/STL Export → PrusaSlicer → Drucker.
    (python3.withPackages (ps: with ps; [
      pythonocc-core
      numpy
    ]))
  ];
}
