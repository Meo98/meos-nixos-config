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

    # warp-mouse-to-focus: AUS (= niri-Default; die Zeile fehlt bewusst).
    #
    #   2026-08-27  eingeschaltet: "spart bei mehreren Monitoren Sucherei"
    #   2026-10-06  beibehalten, als focus-follows-mouse rausflog — mit dem
    #               Argument, der Warp werde dadurch ERST nuetzlich
    #   2026-10-08  RAUS. Das Argument war falsch herum.
    #
    # WARUM RAUS: der Warp haengt am FOKUSWECHSEL, nicht am Monitorwechsel.
    # Jeder Workspace-Wechsel ist aber ein Fokuswechsel — und mit Mod+Rad
    # (binds-nav.nix) passiert das den ganzen Tag. Der Zeiger sprang also bei
    # jedem Scrollen irgendwohin, und die "gesparte Sucherei" war in Wahrheit
    # die Hauptquelle davon: nach einem Warp liegt der Zeiger dort, wo das
    # neue Fenster ist, nicht dort, wo die Hand ihn zuletzt hatte.
    #
    # GEPRUEFT, OB ES EINE ABSTUFUNG GIBT (2026-10-08, gegen `niri validate`
    # von niri 26.04): gueltig sind nur `warp-mouse-to-focus`,
    # mode="center-xy" und mode="center-xy-always". Alle drei steuern, WOHIN
    # gewarpt wird — nicht, BEI WELCHEM Anlass. Ein "nur bei Monitorwechsel"
    # gibt es nicht, also ist es alles oder nichts.
    #
    # Was an seine Stelle tritt: der Zeiger bleibt schlicht liegen, wo er war
    # — vorhersagbar statt hilfreich-gemeint. Zum Orientieren auf dem neuen
    # Monitor dient der Fokusring (layout.nix, Gradient base08 -> base0C).
    #
    # Rueckweg: `warp-mouse-to-focus = {};` hier wieder einfuegen.
  };
}
