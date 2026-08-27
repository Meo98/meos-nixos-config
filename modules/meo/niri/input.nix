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

    # Entspricht dem bisherigen focus_follows_mouse. max-scroll-amount="0%"
    # heisst: Fokus folgt der Maus, aber das Band scrollt dabei nicht mit —
    # sonst wandert der Viewport beim blossen Ueberfahren.
    focus-follows-mouse._props.max-scroll-amount = "0%";

    # Zeiger springt zum neu fokussierten Fenster. Auf zwei Monitoren mit
    # unterschiedlicher Skalierung spart das viel Sucherei.
    warp-mouse-to-focus = {};
  };
}
