# Overlay: Ghostty verliert beim Scrollen den Sub-Zeilen-Rest
#
# src/Surface.zig, scrollCallback(). Ghostty sammelt Scroll-Bewegung in
# mouse.pending_scroll_y und scrollt erst, wenn eine ganze Textzeile
# zusammenkommt. Der Kommentar im Code sagt "save the remainder" -- der Code
# tut es aber nicht:
#
#   const amount = poff / cell_size;                        // f64, z.B. 1.7
#   self.mouse.pending_scroll_y = poff - (amount * cell_size);  // = poff - poff = 0
#   const delta: isize = @intFromFloat(@trunc(amount));      // scrollt 1 Zeile
#
# `amount` ist ein Float, also ist `amount * cell_size` wieder exakt `poff`.
# Der Akkumulator landet auf 0 statt auf dem Rest -> bei 1.7 Zeilen scrollt
# Ghostty eine Zeile und wirft 0.7 weg. Richtig ist der Abzug des
# GERUNDETEN delta. Beide Achsen betroffen (y ~Zeile 3435, x ~Zeile 3459).
#
# Praktische Auswirkung: der Verlust waechst mit der Scroll-Geschwindigkeit
# (bei Lesetempo ~1%, bei schnellem Rollen ~8%) und macht den Zeilentakt
# ungleichmaessig. Er beseitigt NICHT die Zeilen-Quantisierung an sich --
# ein Terminal kann prinzipbedingt nicht feiner als eine Textzeile scrollen.
#
# Gemeldet gegen Ghostty 1.3.1 (= nixpkgs-Stand). Beim naechsten Bump pruefen,
# ob der Patch noch greift; faellt weg sobald upstream gefixt ist.
final: prev: {
  ghostty = prev.ghostty.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/ghostty-scroll-remainder.patch ];
  });
}
