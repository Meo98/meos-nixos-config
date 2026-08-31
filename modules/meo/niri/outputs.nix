# Monitor-Konfiguration.
#
# Die Werte stehen in hosts/<host>/variables.nix unter niriOutputs; diese Datei
# uebersetzt sie nur in die _children/_args-Form, die der KDL-Generator
# erwartet. Gleiche Aufteilung wie input.nix (keyboardLayout) und
# binds-apps.nix (terminal, browser).
#
# MODIFIED 2026-08-31: von fest verdrahteten meo-Werten auf variables.nix
# umgestellt, damit meo-work dasselbe Modul benutzen kann, statt eine zweite
# Kopie zu pflegen, die auseinanderlaeuft.
#
# niri rechnet Positionen in LOGISCHEN Koordinaten. `mode` ist optional: fehlt
# es, waehlt niri den bevorzugten Modus.
#
# Reihenfolge der output-Bloecke ist bedeutungslos, deshalb duerfen sie in einer
# eigenen Datei liegen (anders als window-rule, siehe rules.nix).
{
  host,
  lib,
  ...
}: let
  vars = import ../../../hosts/${host}/variables.nix;
  outputs = vars.niriOutputs or [];

  toOutput = o: {
    output =
      {
        _args = [o.name];
        scale = o.scale;
        position._props = {
          inherit (o) x y;
        };
      }
      // lib.optionalAttrs (o ? mode) {inherit (o) mode;};
  };
in {
  wayland.windowManager.niri.settings._children = map toOutput outputs;
}
