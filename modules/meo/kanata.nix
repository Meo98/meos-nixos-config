{ config, pkgs, ... }:

{
  hardware.uinput.enable = true;
  services.udev.packages = [ pkgs.kanata ];

  services.kanata = {
    enable = true;

    keyboards = {
      "meo-config" = {
        # Die Charybdis hat eigene Home-Row-Mods, Combos und Ebenen in der
        # RMK-Firmware (per Vial aenderbar). Ohne diese Ausnahme lief jeder
        # Anschlag ZUSAETZLICH durch kanata: a s d f g h j k l u o n und die
        # Leertaste kamen erst beim Loslassen (tap-hold), i/p warteten bis zu
        # 80 ms und w/e bis zu 40 ms auf einen Akkord. Das war die spuerbare
        # Verzoegerung beim Tippen (2026-10-16). kanata vergleicht die Namen
        # EXAKT; die Liste deckt USB ("BastardKB ...") und Bluetooth ab.
        # Namen nachschlagen: journalctl -u kanata-meo-config | grep registering
        extraDefCfg = ''
          process-unmapped-keys yes
          ;; Custom-Boards mit eigener Firmware (Vial/QMK/RMK) nicht anfassen:
          ;; Laptop-Tastatur und normale Tastaturen (z. B. Logitech) bleiben
          ;; unter kanata, die Split-Boards liefern ihre Layouts selbst.
          ;; Namen exakt wie in /proc/bus/input/devices (N: Name=...).
          linux-dev-names-exclude (
            "Pilot W-CORNE"
            "Pilot W-CORNE System Control"
            "Pilot W-CORNE Consumer Control"
            "BastardKB Charybdis Mini"
            "BastardKB Charybdis Mini Keyboard"
            "BastardKB Charybdis Mini Mouse"
            "BastardKB Charybdis Mini Consumer Control"
            "BastardKB Charybdis Mini System Control"
            "Charybdis Mini"
            "Charybdis Mini Keyboard"
            "Charybdis Mini Mouse"
            "Charybdis Mini Consumer Control"
            "Charybdis Mini System Control"
          )
        '';

        config = ''
          (defsrc
            caps a s d f g h j k l u i o p
            n w e r x c v spc
            lbrc apos scln
          )

          ;; -----------------------------
          ;; CHORDS
          ;; i+p => Enter   (u bleibt frei für ü-hold)
          ;; w+e => Backspace
          ;; -----------------------------
          (defchords enter_chord 80
            (i  ) i
            (  p) p
            (i p) ret
          )

          (defchords bs_chord 40
            (w  ) w
            (  e) e
            (w e) bspc
          )

          (defalias
            ;; --- Chord-Keys ---
            my_i (chord enter_chord i)
            my_p (chord enter_chord p)
            my_w (chord bs_chord w)
            my_e (chord bs_chord e)

            ;; --- Caps: tap = Esc, hold = Super ---
            cap (tap-hold 200 200 esc lmet)

            ;; --- Home-row mods ---
            met_g (tap-hold 200 200 g lmet)
            alt_s (tap-hold 200 200 s lalt)
            ctl_f (tap-hold 200 200 f lctl)
            sft_d (tap-hold 200 200 d lsft)

            met_h (tap-hold 200 200 h rmet)
            alt_l (tap-hold 200 200 l ralt)
            ctl_j (tap-hold 200 200 j rctl)
            sft_k (tap-hold 200 200 k rsft)

            ;; -----------------------------
            ;; Umlaute klein per HOLD (ohne Unicode)
            ;; tap-hold-release => kein "ooooo" Auto-Repeat beim Halten
            ;; CH-DE: lbrc/apos/scln sind ü/ä/ö (wenn dein Kanata-Device richtig layouted ist)
            ;; -----------------------------
            u_um (tap-hold-release 220 220 u lbrc)   ;; hold -> ü
            o_um (tap-hold-release 220 220 o scln)   ;; hold -> ö
            a_um (tap-hold-release 220 220 a apos)   ;; hold -> ä

            ;; -----------------------------
            ;; Groß-Umlaute per CapsLock-Trick:
            ;; caps on -> umlaut key -> caps off
            ;; (funktioniert nur zuverlässig wenn CapsLock normalerweise AUS ist)
            ;; -----------------------------
            Ue (macro 20 caps 20 lbrc 20 caps)  ;; Ü
            Oe (macro 20 caps 20 scln 20 caps)  ;; Ö
            Ae (macro 20 caps 20 apos 20 caps)  ;; Ä

            ;; "UMLCAPS"-Layer solange SPACE gehalten wird
            umlL (layer-while-held umlcaps)
            spc_uml (tap-hold-release 170 170 spc @umlL)

            ;; Numbers layer (wie bei dir)
            numL (layer-while-held numbers)
            n_num (tap-hold-release 200 200 n @numL)
          )

          ;; -----------------------------
          ;; DEFAULT LAYER
          ;; -----------------------------
          (deflayer default
            @cap @a_um @alt_s @sft_d @ctl_f @met_g @met_h @ctl_j @sft_k @alt_l @u_um @my_i @o_um @my_p
            @n_num @my_w @my_e r x c v @spc_uml
            lbrc apos scln
          )

          ;; -----------------------------
          ;; UMLCAPS LAYER (SPACE gehalten)
          ;; u/o/a geben Ü/Ö/Ä
          ;; -----------------------------
          (deflayer umlcaps
            @cap @Ae @alt_s @sft_d @ctl_f @met_g @met_h @ctl_j @sft_k @alt_l @Ue @my_i @Oe @my_p
            @n_num @my_w @my_e r x c v spc
            lbrc apos scln
          )

          ;; -----------------------------
          ;; NUMBERS
          ;; -----------------------------
          (deflayer numbers
            @cap a 4 5 6 g h j k l _ _ _ _
            n 1 2 3 7 8 9 0
            lbrc apos scln
          )
        '';
      };
    };
  };

  systemd.services.kanata-meo-config = {
    # Kanata beendet sich mit Exit 1, wenn eine Tastatur mitten im Lesen
    # verschwindet (USB-Reconnect der Charybdis -> "failed read: No such
    # device"). Das nixpkgs-Modul setzt kein Restart, der Dienst bliebe
    # dann dauerhaft auf "failed". Darum: immer neu starten, ohne Start-Limit,
    # damit auch ein laengeres Abstecken der Tastatur den Dienst nicht sperrt.
    # (Am 11.10.2026 auf meo passiert: Charybdis mehrfach geflasht,
    # kanata lag danach neun Stunden tot.)
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = "always";
      RestartSec = 1;
      DynamicUser = pkgs.lib.mkForce false;
      User = pkgs.lib.mkForce "root";
      Group = pkgs.lib.mkForce "root";
    };
  };
}
