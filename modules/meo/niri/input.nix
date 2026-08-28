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

    # Entspricht dem bisherigen focus_follows_mouse aus Hyprland.
    #
    # MODIFIED 2026-08-28: max-scroll-amount="0%" wieder ENTFERNT. Der Wert
    # heisst laut niri-Doku nicht "fokussiere ohne zu scrollen", sondern
    # "fokussiere gar nicht, wenn dafuer mehr als 0% gescrollt werden muesste"
    # — also nur bei Fenstern, die schon vollstaendig sichtbar sind. Im
    # Scroll-Layout ist die Nachbarspalte fast immer angeschnitten (Spalten
    # sind 2/3 breit, aufs eDP passen ~1.5), deshalb passierte beim
    # Drueberfahren nichts und man musste erst klicken.
    #
    # Der Randfall, gegen den "0%" in der niri-FAQ empfohlen wird (CSD-Resize-
    # Raender lugen ueber die Monitorkante und loesen ungewollt Fokus aus), ist
    # hier schon durch `prefer-no-csd` in default.nix abgedeckt — das ist die
    # zweite Fix-Option derselben FAQ-Antwort.
    focus-follows-mouse = {};

    # Zeiger springt zum neu fokussierten Fenster. Auf zwei Monitoren mit
    # unterschiedlicher Skalierung spart das viel Sucherei. Kollidiert nicht
    # mit focus-follows-mouse: der Default-Modus warpt nur, wenn der Zeiger
    # AUSSERHALB des neu fokussierten Fensters war — beim Hover ist er drin.
    warp-mouse-to-focus = {};
  };
}
