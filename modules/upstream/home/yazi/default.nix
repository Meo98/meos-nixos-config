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
    };

    initLua = ''
      require("full-border"):setup()
      require("git"):setup()
      require("smart-enter"):setup {
        open_multi = true,
      }

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
}
