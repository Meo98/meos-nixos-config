# Eingabegeraete. keyboardLayout kommt aus hosts/<host>/variables.nix, damit
# der Wert nicht doppelt gepflegt wird (dort steht "ch").
{host, ...}: let
  vars = import ../../../hosts/${host}/variables.nix;
  inherit (vars) keyboardLayout;
in {
  wayland.windowManager.niri.settings.input = {
    keyboard = {
      xkb.layout = keyboardLayout;
      repeat-delay = 400;
      repeat-rate = 40;
    };

    touchpad = {
      tap = {};
      natural-scroll = {};
      dwt = {}; # disable-while-typing
      accel-profile = "adaptive";
    };

    mouse.accel-profile = "flat";

    # focus-follows-mouse: AUS (= niri-Default; die Zeile fehlt bewusst).
    #
    # Historie, damit das nicht im Kreis geht:
    #   2026-08-27  eingeschaltet, um Hyprlands focus_follows_mouse nachzubauen
    #   2026-08-28  max-scroll-amount="0%" probiert und wieder entfernt — der
    #               Wert heisst nicht "fokussiere ohne zu scrollen", sondern
    #               "fokussiere gar nicht, wenn dafuer mehr als 0% gescrollt
    #               werden muesste". Im Scroll-Layout ist die Nachbarspalte
    #               fast immer angeschnitten, also passierte gar nichts mehr.
    #   2026-10-06  GANZ RAUS.
    #
    # WARUM RAUS: auf drei Monitoren ist der Zeiger kein Fokus-Zeiger mehr,
    # sondern liegt irgendwo herum. Jede Mausbewegung ueber einen fremden
    # Schirm riss den Fokus mit — besonders fies zusammen mit
    # warp-mouse-to-focus unten: Tastendruck warpt den Zeiger auf Monitor B,
    # ein Zucken der Hand bringt den Fokus ueber ein Fenster, das zufaellig
    # unter dem neuen Zeigerort liegt. Mit zwei Schirmen war das selten genug,
    # mit dreien nicht mehr.
    #
    # Das Gegenstueck dazu ist die Tastatur-Navigation seit 2026-10-06:
    # Mod+Ctrl+hjkl (focus-monitor-*) und der Rand-Ueberlauf von Mod+hjkl in
    # binds-nav.nix. Die MAUS hat den Monitorwechsel ersetzt, nicht verloren.
    #
    # Rueckweg: `focus-follows-mouse = {};` hier wieder einfuegen.

    # Zeiger springt zum neu fokussierten Fenster. Bei drei Monitoren mit
    # unterschiedlicher Skalierung spart das viel Sucherei — und wird durch
    # das Abschalten von focus-follows-mouse ERST richtig nuetzlich: vorher
    # konnte der Warp selbst wieder einen Hover-Fokus ausloesen, jetzt folgt
    # der Zeiger dem Fokus nur noch in eine Richtung.
    warp-mouse-to-focus = {};
  };
}
