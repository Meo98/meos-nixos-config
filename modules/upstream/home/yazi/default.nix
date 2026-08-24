{pkgs, ...}: let
  settings = import ./yazi.nix;
  keymap = import ./keymap.nix;
  theme = import ./theme.nix;
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
      require("yatline"):setup()

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
    imagemagick
    chafa
    fd
    p7zip
  ];
}
