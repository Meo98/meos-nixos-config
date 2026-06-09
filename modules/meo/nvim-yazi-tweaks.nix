{lib, ...}:
# Aktiviert render-markdown.nvim in nixvim und setzt nvim als Default-Editor.
# Ergaenzt die existierende nixvim-Konfiguration aus
# modules/upstream/home/editors/nixvim.nix (30+ Plugins schon enabled).
#
# Zusammenspiel mit Yazi:
#   - .md Files werden in Yazi via Enter mit nvim geoeffnet (render-markdown
#     macht Live-Headings/Bold/Lists waehrend Edit)
#   - 'glow' bleibt als 2. Option im .md Opener-Menue (Shift+Enter)
#     fuer reine Read-Only Preview
{
  # Default-Editor von hx auf nvim umstellen (ueberschreibt evil-helix.nix:24)
  home.sessionVariables.EDITOR = lib.mkForce "nvim";

  # render-markdown.nvim: Live-rendered Markdown waehrend Edit
  # https://github.com/MeanderingProgrammer/render-markdown.nvim
  programs.nixvim.plugins.render-markdown = {
    enable = true;
    settings = {
      # Headings mit Icons statt # Zeichen
      heading = {
        icons = ["󰉫 " "󰉬 " "󰉭 " "󰉮 " "󰉯 " "󰉰 "];
        sign = false;
      };
      # Code-Bloecke mit dezenter Background-Hervorhebung
      code = {
        style = "language";
        position = "right";
        width = "block";
      };
      # Bullet-Lists mit Icons
      bullet = {
        icons = ["●" "○" "◆" "◇"];
      };
      # Checkbox-Rendering
      checkbox = {
        unchecked.icon = "󰄱 ";
        checked.icon = "󰱒 ";
      };
      # Tables mit echten Linien
      pipe_table = {
        style = "full";
        cell = "padded";
      };
      # Standard-Filetypes inkl. quarto/rmd
      file_types = ["markdown" "Avante" "copilot-chat"];
    };
  };
}
