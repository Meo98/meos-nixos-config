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
      "mtime-ch" = pkgs.writeTextDir "main.lua" ''
        return {
          entry = function(self, job)
            local time = math.floor(job.file.cha.modified or 0)
            if time == 0 then return ui.Line("") end
            return ui.Line(os.date(" %d/%m/%y %H:%M", time))
          end
        }
      '';
    };

    initLua = ''
      require("full-border"):setup()
         require("git"):setup()
         require("smart-enter"):setup {
           open_multi = true,
         }
    '';
  };
}
