{pkgs, ...}:
# MicroPython-Workflow fuer Neovim — Ersatz fuer die MicroPico-Extension in
# VS Code (Raspberry Pi Pico Projekte, z.B. ~/bocca_ir_audio_trigger).
#
# Bausteine:
#   1. mpremote (offizielles MicroPython-CLI) dauerhaft im PATH
#   2. micropython.nvim (jim-at-jibba) — nicht in nixpkgs, daher via
#      buildVimPlugin von GitHub gepinnt
#   3. Keymaps unter <leader>m analog zu den MicroPico-Buttons
#
# Workflow: nvim im firmware/-Ordner des Projekts oeffnen (Upload-All laedt
# rekursiv das cwd hoch). Port/Baud liegen in einer .micropython-Datei im
# Projektordner (per :MPInit erzeugbar oder von Hand, Format: PORT=auto).
{
  # mpremote systemweit statt ad-hoc via nix-shell
  home.packages = [pkgs.mpremote];

  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        pname = "micropython-nvim";
        version = "unstable-2026-07";
        src = pkgs.fetchFromGitHub {
          owner = "jim-at-jibba";
          repo = "micropython.nvim";
          rev = "f124d6b166bd370338481e225f7a39b7d4a56742";
          hash = "sha256-tJ50rgrhPYZ0LPjN90nz7JwEtyAZH97YnHFK4SPaYZc=";
        };
      })
    ];

    extraConfigLua = ''
      require("micropython_nvim").setup({})
      -- which-key Gruppenlabel fuer <leader>m (pcall: robust falls API aendert)
      pcall(function()
        require("which-key").add({ { "<leader>m", group = "MicroPython" } })
      end)
    '';

    keymaps = [
      {
        key = "<leader>mr";
        mode = ["n"];
        action = "<cmd>MPRun<CR>";
        options.desc = "MicroPython: aktuellen Buffer auf Pico ausfuehren";
      }
      {
        key = "<leader>mu";
        mode = ["n"];
        action = "<cmd>MPUpload<CR>";
        options.desc = "MicroPython: aktuelle Datei hochladen";
      }
      {
        key = "<leader>ma";
        mode = ["n"];
        action = "<cmd>MPUploadAll<CR>";
        options.desc = "MicroPython: ganzes Projekt hochladen (cwd)";
      }
      {
        key = "<leader>mp";
        mode = ["n"];
        action = "<cmd>MPRepl<CR>";
        options.desc = "MicroPython: REPL oeffnen (print-Output live)";
      }
      {
        key = "<leader>mx";
        mode = ["n"];
        action = "<cmd>MPReset<CR>";
        options.desc = "MicroPython: Pico soft-resetten (main.py neu starten)";
      }
      {
        key = "<leader>mf";
        mode = ["n"];
        action = "<cmd>MPListFiles<CR>";
        options.desc = "MicroPython: Dateien auf dem Pico auflisten";
      }
      {
        key = "<leader>ms";
        mode = ["n"];
        action = "<cmd>MPSetPort<CR>";
        options.desc = "MicroPython: Serial-Port waehlen";
      }
    ];
  };
}
