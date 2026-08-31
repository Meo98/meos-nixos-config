# Overlay: Ghostty kann kein High-Resolution-Scrolling
#
# Betrifft src/Surface.zig, scrollCallback(). Drei Fehler in einer Funktion,
# alle drei treffen genau die Keyball-Trackball-Kette (Firmware sendet
# REL_WHEEL_HI_RES -> niri reicht es als wl_pointer.axis_value120 durch ->
# GTK4 liefert Bruchteile eines Wheel-Ticks an Ghostty).
#
# 1) DER EIGENTLICHE BOECK -- Hi-Res-Ticks werden auf einen ganzen Tick
#    hochgeklemmt:
#
#      const yoff_max: f64 = if (yoff > 0) @max(yoff, 1) else @min(yoff, -1);
#
#    Der Kommentar darueber begruendet das ausdruecklich mit macOS (dort
#    rampt das System die Betraege statt Precision-Events zu schicken). Unter
#    Linux ist ein Wert < 1.0 aber ein echter Hi-Res-Tick. Folge: JEDES
#    Scroll-Event, egal wie winzig, zaehlt als voller Wheel-Klick. Damit
#    haengt die Scroll-Geschwindigkeit nicht mehr an der zurueckgelegten
#    Ballstrecke, sondern an der EVENT-RATE des Geraets -- bei ~100-250
#    Events/s also 100-250 Zeilen/s, und die Geschwindigkeitskurve aus der
#    Keyball-Firmware ist komplett wirkungslos. Fix: klemmen nur auf macOS.
#
# 2) Der Sub-Zeilen-Rest wird verworfen statt aufgehoben:
#
#      const amount = poff / cell_size;                            // f64, z.B. 1.7
#      self.mouse.pending_scroll_y = poff - (amount * cell_size);  // = poff - poff = 0
#      const delta: isize = @intFromFloat(@trunc(amount));         // scrollt 1 Zeile
#
#    `amount` ist ein Float, also ist `amount * cell_size` wieder exakt
#    `poff`. Der Akkumulator landet auf 0 statt auf dem Rest. Der Verlust
#    waechst mit der Scroll-Geschwindigkeit (Lesetempo <1%, schnelles Rollen
#    ~20%) und macht den Zeilentakt ungleichmaessig. Richtig ist der Abzug
#    des GERUNDETEN delta. Beide Achsen betroffen.
#
# 3) Die x-Achse rundete Nicht-Precision-Ticks direkt auf ganze Spalten
#    (@round(xoff)), ohne Akkumulator. Jeder horizontale Hi-Res-Tick mit
#    |xoff| < 0.5 wurde also zu 0 -- horizontales Scrollen mit dem Ball war
#    schlicht tot. Laeuft jetzt ueber denselben Akkumulator wie y.
#
# Was der Patch NICHT tut: die Zeilen-Quantisierung beseitigen. Ein Terminal
# kann prinzipbedingt nicht feiner als eine Textzeile scrollen. Er sorgt nur
# dafuer, dass die Zeilen im richtigen Takt kommen.
#
# Nach dem Patch gilt: Zeilen pro Detent = ticks * scale_factor * discrete.
# scale_factor ist der GANZZAHLIGE GTK-Scale (eDP-1: niri-Scale 1.6 -> GTK 2),
# weil scaledCoordinates() in src/apprt/gtk/class/surface.zig auch die
# Scroll-Deltas mitskaliert. Deshalb steht mouse-scroll-multiplier in
# ghostty.nix auf discrete:1.5 -> 3 Zeilen pro Detent (Desktop-Konvention).
#
# Gegen Ghostty 1.3.1 (= nixpkgs-Stand). Beim naechsten Bump pruefen, ob der
# Patch noch greift; faellt weg sobald upstream gefixt ist.
final: prev: {
  ghostty = prev.ghostty.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/ghostty-hires-scroll.patch ];
  });
}
