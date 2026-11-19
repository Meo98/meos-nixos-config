{pkgs, ...}: let
  settings = import ./yazi.nix;
  keymap = import ./keymap.nix;
  theme = import ./theme.nix;

  # ADDED 2026-11-19: Spickzettel in der Kopfzeile von yazi (oben rechts).
  # Jeder Eintrag ist ein Stück Text; unten werden sie mit " · " verbunden.
  # Einträge, die sitzen, hier durch neue ersetzen. Die Zeile muss in die
  # Fensterbreite passen, sonst wird sie abgeschnitten. Alle Tasten: `~` in yazi.
  spickzettel = [
    "~ Hilfe"
    "Leer wählen"
    "y kopieren"
    "x ausschneiden"
    "p einfügen"
    "d Papierkorb"
    "r umbenennen"
    "a neu"
    "/ suchen"
    ", sortieren"
    "i Spalten"
  ];
in {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    shellWrapperName = "yy";
    settings = settings;
    keymap = keymap;
    theme = theme;
    plugins = {
      lazygit = pkgs.yaziPlugins.lazygit;
      full-border = pkgs.yaziPlugins.full-border;
      git = pkgs.yaziPlugins.git;
      smart-enter = pkgs.yaziPlugins.smart-enter;
      glow = pkgs.yaziPlugins.glow;
      # ADDED 2026-08-20: kuratierte Plugin-Erweiterung (Keybinds in keymap.nix,
      # ouch-Previewer in yazi.nix). Alle aus pkgs.yaziPlugins (reproduzierbar).
      jump-to-char = pkgs.yaziPlugins.jump-to-char;
      smart-filter = pkgs.yaziPlugins.smart-filter;
      mount = pkgs.yaziPlugins.mount;
      chmod = pkgs.yaziPlugins.chmod;
      ouch = pkgs.yaziPlugins.ouch;
      bookmarks = pkgs.yaziPlugins.bookmarks;
      # ADDED 2026-11-19: Vorschau maximieren (T), Papierkorb zurückholen (u/U).
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      restore = pkgs.yaziPlugins.restore;
      # what-size ist nicht in nixpkgs, darum direkt von GitHub auf einen festen
      # Stand gepinnt (braucht yazi >= 26.8.15). Taste: i g.
      what-size = pkgs.fetchFromGitHub {
        owner = "pirafrank";
        repo = "what-size.yazi";
        rev = "1cb456f8c428a393a65708b45b8c56404d52f326";
        hash = "sha256-lhanC44L4haM7cgqCOhfxk0Rpi/FueBgIdXDiXuzevc=";
      };
      # MODIFIED: Deprecation-Fix — yatline 0.5.0 ruft in main.lua noch die alte
      # File:icon()-API auf (`hovered:icon().text`) -> Warnung beim yazi-Start.
      # Patch auf die neue th.icon:match(file)-API, mit Leer-Fallback falls eine
      # Datei kein Icon hat. (th ist ein yazi-Runtime-Global.)
      yatline = pkgs.yaziPlugins.yatline.overrideAttrs (o: {
        postInstall = (o.postInstall or "") + ''
          sed -i 's/hovered:icon()/(th.icon:match(hovered) or { text = "" })/' "$out/main.lua"
        '';
      });
    };

    initLua = ''
      require("full-border"):setup()
      require("git"):setup()
      require("smart-enter"):setup {
        open_multi = true,
      }
      -- ADDED 2026-08-20: yatline (Lualine-artige Status/Header-Line). Ohne
      -- config-Argument nutzt setup() die eingebauten Defaults (safe).
      -- MODIFIED 2026-11-19: Kopfzeile rechts zeigt den Spickzettel (Liste
      -- `spickzettel` oben in dieser Datei) statt des ausgeschriebenen Datums.
      require("yatline"):setup({
        header_line = {
          left = {
            section_a = { { type = "line", name = "tabs" } },
          },
          right = {
            section_a = { { type = "string", name = "date", params = { "%H:%M" } } },
            section_c = {
              { type = "string", custom = true, name = "${builtins.concatStringsSep " · " spickzettel}" },
            },
          },
        },
      })

      -- ADDED 2026-11-19: Standard-Spalte wie im Windows-Explorer: Grösse und
      -- Änderungsdatum, rechtsbündig, damit die Werte untereinander stehen.
      -- Ordner haben keine Grösse (yazi rechnet sie nicht von sich aus aus).
      function Linemode:groesse_datum()
        local time = math.floor(self._file.cha.mtime or 0)
        local datum = time == 0 and "" or os.date("%d.%m.%Y %H:%M", time)
        local size = self._file:size()
        local groesse = size and ya.readable_size(size) or ""
        return string.format("%8s  %16s", groesse, datum)
      end

      function Linemode:mtime_ch()
        local time = math.floor(self._file.cha.mtime or 0)
        if time == 0 then return "" end
        return os.date(" %d.%m.%Y %H:%M", time)
      end

      function Linemode:btime_ch()
        local time = math.floor(self._file.cha.btime or 0)
        if time == 0 then return "" end
        return os.date(" %d.%m.%Y %H:%M", time)
      end
    '';
  };

  # ADDED 2026-08-20: CLI-Tools, die die yazi-Plugins/Previews brauchen.
  # ouch = Archiv-Handling (ouch-Plugin), chafa = Bild-Preview-Fallback,
  # imagemagick/fd/p7zip = Previews & Suche.
  home.packages = with pkgs; [
    ouch
    trash-cli # ADDED 2026-11-19: braucht das restore-Plugin (u/U)
    imagemagick
    chafa
    fd
    p7zip
  ];
}
