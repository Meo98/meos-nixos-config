{ pkgs, ... }:
# Schriften für grafische Arbeiten (DesignCraft/VectorCraft: Plakate, Poster,
# Flyer; auch Affinity, LibreOffice, Browser). Systemweit für beide Hosts.
#
# Kern ist `google-fonts`, auf eine Auswahl beschränkt: ohne `fonts = […]`
# landen alle ~1900 Familien (über 1 GB) im System und machen jede
# Schriftliste unbenutzbar. Die Namen sind die Familiennamen von
# fonts.google.com (Leerzeichen werden vom Paket selbst entfernt); das Paket
# installiert statische Schnitte und Variable Fonts, soweit vorhanden.
# Stylix' UI-Schriften (Noto, JetBrains Mono) bleiben davon unberührt.
let
  googleAuswahl = pkgs.google-fonts.override {
    fonts = [
      # --- Headline / Display: kräftig, schmal, für Plakate ------------------
      "Anton" "Bebas Neue" "Oswald" "League Gothic" "Teko" "Fjalla One"
      "Archivo Black" "Archivo Narrow" "Alfa Slab One" "Abril Fatface" "Ultra"
      "Unbounded" "Syne" "Space Grotesk" "Staatliches" "Paytone One"
      "Bungee" "Righteous" "Monoton" "Rubik Mono One" "Black Ops One"
      "Bangers" "Luckiest Guy" "Lilita One" "Passion One" "Titan One" "Bowlby One"
      "Fredoka" "Chewy" "Comfortaa" "Orbitron" "Chakra Petch" "Press Start 2P"
      "Creepster" "Rye" "Special Elite"
      # --- Script / Handschrift ----------------------------------------------
      "Pacifico" "Lobster" "Caveat" "Dancing Script" "Great Vibes" "Satisfy"
      "Amatic SC" "Permanent Marker" "Shadows Into Light" "Patrick Hand" "Kalam"
      "Sacramento" "Courgette" "Yellowtail"
      # --- Sans für Fliesstext und Layout ------------------------------------
      "Inter" "Roboto" "Roboto Condensed" "Open Sans" "Lato" "Poppins" "Raleway"
      "Nunito" "Work Sans" "Manrope" "DM Sans" "Rubik" "Outfit" "Plus Jakarta Sans"
      "Josefin Sans" "Quicksand" "Barlow" "Barlow Condensed" "Lexend" "Figtree"
      "Karla" "Mulish" "Source Sans 3" "Fira Sans" "Public Sans" "Red Hat Display"
      "Sora" "Urbanist" "Bricolage Grotesque" "Instrument Sans" "Geist"
      "Alegreya Sans" "Atkinson Hyperlegible"
      # --- Serif ---------------------------------------------------------------
      "Playfair Display" "Lora" "Merriweather" "Libre Baskerville" "EB Garamond"
      "Cormorant Garamond" "Crimson Pro" "DM Serif Display" "Fraunces" "Bodoni Moda"
      "Cinzel" "Libre Caslon Text" "Spectral" "Source Serif 4" "Instrument Serif"
      "Alegreya" "Roboto Slab" "Zilla Slab" "Arvo" "Bitter" "Josefin Slab"
      # --- Mono (für Gestaltung, nicht Terminal) ------------------------------
      "Space Mono" "Fira Code" "Roboto Mono" "DM Mono" "Courier Prime"
    ];
  };
in {
  fonts.packages = [
    googleAuswahl
    pkgs.ibm-plex                   # Plex Sans/Serif/Mono/Condensed, grosse Familie
    pkgs.libertinus                 # klassische Buchschrift mit Mathe/Kapitälchen
    pkgs.league-of-moveable-type    # League Spartan, Gothic, Script, Junction, Raleway-Original u. a.
    pkgs.atkinson-hyperlegible-next # besonders gut lesbar (Beschriftungen, Ausstellung)
  ];
}
