{lib, ...}: let
  # Catppuccin Mocha statt Stylix-Farben (User-Wunsch).
  # Stylix's nixvim-Target wird deaktiviert, damit das in nixvim.nix
  # konfigurierte 'colorschemes.catppuccin' nicht von Stylix ueberschrieben wird.
in
# Erweiterungen zum upstream-nixvim-Setup
# (modules/upstream/home/editors/nixvim.nix hat schon 30+ Plugins).
#
# Hier wird hinzugefuegt:
#   1. Helix-aehnliche Editor-Settings (relativenumber, scrolloff, undofile, ...)
#   2. render-markdown.nvim fuer Live-Markdown
#   3. Helix-Killer-Features: mini.move (Alt+j/k Line-Move), neoscroll
#      (smooth scroll), nvim-ufo (modern fold), dressing (besseres UI),
#      treesitter-context.enable = true (sticky func-headers)
#   4. virtual_lines diagnostics auf cursor-line (Helix-Style)
#   5. Center-cursor nach Scroll/Search (zz auto)
#   6. EDITOR=nvim als Session-Variable (ueberschreibt evil-helix.nix)
{
  # ============================================================
  # 0) Stylix-Override fuer nvim deaktivieren (Catppuccin Mocha behalten)
  # ============================================================
  stylix.targets.nixvim.enable = false;

  # ============================================================
  # 1) Default-Editor auf nvim (kombiniert mit hyprland/env.nix)
  # ============================================================
  home.sessionVariables.EDITOR = lib.mkForce "nvim";

  programs.nixvim = {
    # ============================================================
    # 2) Helix-aehnliche Editor-Settings
    # ============================================================
    opts = {
      # Helix-Style: relative numbers + absolute aktuelle Zeile
      number = lib.mkForce true;
      relativenumber = lib.mkForce true;

      # Padding beim Scrollen (kein Cursor am Rand)
      scrolloff = 8;
      sidescrolloff = 8;

      # Mouse in allen Modes
      mouse = "a";

      # Persistent Undo (ueberlebt Neustart)
      undofile = true;

      # Smart Case Search wie Helix
      ignorecase = true;
      smartcase = true;

      # Spell-Check mehrsprachig (DE + EN). Upstream nixvim.nix setzt nur "en"
      # was deutsche Texte komplett rot unterstreicht.
      spelllang = lib.mkForce ["en" "de"];

      # Schneller diagnostic updates
      updatetime = lib.mkForce 100;
      timeoutlen = 300;

      # Schoenere Window-Borders + Trennlinien.
      # Wichtig: fillchars-Werte muessen einzelne Grapheme sein.
      # Nerd-Font-Icons koennen je nach Terminal/Font als 0 oder >1
      # Grapheme zaehlen -> E1511. Daher hier portable Unicode-Box-
      # Drawing-Chars die in jedem monospace-Font ein einzelnes
      # Zeichen sind.
      fillchars = {
        eob = " ";
        fold = " ";
        foldopen = "▾";
        foldsep = " ";
        foldclose = "▸";
      };

      # List/Whitespace-Indikatoren (nur subtle)
      list = true;
      listchars = {
        tab = "│ ";
        trail = "·";
        nbsp = "␣";
      };

      # Cursorline nur fuer Line-Number-Highlight (subtle)
      cursorlineopt = "number";

      # Bessere Splits (neue Fenster rechts/unten)
      splitright = true;
      splitbelow = true;

      # Modern fold defaults (nvim-ufo wird das uebernehmen)
      foldlevel = 99;
      foldlevelstart = 99;
      foldenable = true;

      # 24-bit colors (schon an, defensiv)
      termguicolors = lib.mkForce true;
    };

    # ============================================================
    # 3) Plugins hinzufuegen
    # ============================================================
    plugins = {
      # Live-rendered Markdown (Headings als Icons, Code-Bloecke mit Border, etc.)
      render-markdown = {
        enable = true;
        settings = {
          # Sign-Spalte abschalten (kein "H1"/"H2" links neben dem Heading)
          sign = {enabled = false;};
          heading = {
            icons = ["󰉫 " "󰉬 " "󰉭 " "󰉮 " "󰉯 " "󰉰 "];
            position = "overlay";
          };
          code = {
            style = "language";
            position = "right";
            width = "block";
          };
          bullet.icons = ["●" "○" "◆" "◇"];
          checkbox = {
            unchecked.icon = "󰄱 ";
            checked.icon = "󰱒 ";
          };
          pipe_table = {
            style = "full";
            cell = "padded";
          };
          file_types = ["markdown" "Avante" "copilot-chat"];
        };
      };

      # Treesitter-Context: sticky function/class header beim Scrollen
      # (war im upstream auf false gesetzt - jetzt an)
      treesitter-context = {
        enable = lib.mkForce true;
        settings = {
          max_lines = 3;
          min_window_height = 20;
          mode = "cursor";
        };
      };

      # mini.move: Alt+j/k Zeilen verschieben (Helix-Style)
      mini = {
        enable = true;
        modules = {
          move = {
            mappings = {
              left = "<M-h>";
              right = "<M-l>";
              down = "<M-j>";
              up = "<M-k>";
              line_left = "<M-h>";
              line_right = "<M-l>";
              line_down = "<M-j>";
              line_up = "<M-k>";
            };
          };
        };
      };

      # Smooth scrolling (Ctrl+d/u/f/b mit animation)
      neoscroll = {
        enable = true;
        settings = {
          easing = "quadratic";
          duration_multiplier = 0.7;
        };
      };

      # Modern Folding via Treesitter
      nvim-ufo = {
        enable = true;
        settings = {
          provider_selector = ''
            function(_, _, _) return {"treesitter", "indent"} end
          '';
        };
      };

      # Besseres UI fuer vim.ui.input/select (rename, code-action, etc.)
      dressing.enable = true;

      # Lualine theme-name fix: "catppuccin" -> "catppuccin-mocha"
      # (neuere Catppuccin-Version hat Flavour als Suffix im Theme-Namen)
      lualine.settings.options.theme = lib.mkForce "catppuccin-mocha";

      # Schnellere telescope-Suche
      telescope = {
        extensions = {
          fzf-native.enable = true;
        };
      };
    };

    # ============================================================
    # 4) Zusaetzliche Keymaps (Helix-Feeling)
    # ============================================================
    keymaps = [
      # Center cursor nach Half-Page-Scroll
      {
        key = "<C-d>";
        mode = ["n"];
        action = "<C-d>zz";
        options.desc = "Half page down (centered)";
      }
      {
        key = "<C-u>";
        mode = ["n"];
        action = "<C-u>zz";
        options.desc = "Half page up (centered)";
      }
      # Center cursor nach Suche
      {
        key = "n";
        mode = ["n"];
        action = "nzzzv";
        options.desc = "Next search (centered)";
      }
      {
        key = "N";
        mode = ["n"];
        action = "Nzzzv";
        options.desc = "Prev search (centered)";
      }
      # nvim-ufo Keymaps fuer Folding
      {
        key = "zR";
        mode = ["n"];
        action.__raw = "function() require('ufo').openAllFolds() end";
        options.desc = "Open all folds";
      }
      {
        key = "zM";
        mode = ["n"];
        action.__raw = "function() require('ufo').closeAllFolds() end";
        options.desc = "Close all folds";
      }
      # Ctrl+P wie VSCode/Helix space+f
      {
        key = "<C-p>";
        mode = ["n"];
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find files";
      }
      # System-Yank/Paste shortcuts
      {
        key = "<leader>y";
        mode = ["n" "v"];
        action = "\"+y";
        options.desc = "Yank to system clipboard";
      }
      {
        key = "<leader>p";
        mode = ["n" "v"];
        action = "\"+p";
        options.desc = "Paste from system clipboard";
      }
    ];

    # ============================================================
    # 5) Lua-Tweaks: Diagnostics Helix-Style + sonstige Polish
    # ============================================================
    extraConfigLua = ''
      -- Helix-Style: virtual_lines nur auf cursor-line (multi-line
      -- Diagnostic-Display), virtual_text auf den anderen Zeilen.
      vim.diagnostic.config({
        virtual_lines = { only_current_line = true },
        virtual_text = {
          prefix = "●",
          spacing = 2,
          source = "if_many",
        },
        update_in_insert = false,
        severity_sort = true,
        underline = true,
        signs = true,
        float = {
          border = "rounded",
          source = "always",
        },
      })

      -- Hover/Signature Help mit rounded borders
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
        vim.lsp.handlers.hover, { border = "rounded" }
      )
      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
        vim.lsp.handlers.signature_help, { border = "rounded" }
      )

      -- Highlight on yank (visual feedback)
      vim.api.nvim_create_autocmd("TextYankPost", {
        callback = function()
          vim.highlight.on_yank({ timeout = 200 })
        end,
      })

      -- Auto-resize splits beim Window-Resize
      vim.api.nvim_create_autocmd("VimResized", {
        command = "tabdo wincmd =",
      })

      -- Restore cursor position on file open
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function()
          local mark = vim.api.nvim_buf_get_mark(0, "\"")
          if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
            vim.api.nvim_win_set_cursor(0, mark)
          end
        end,
      })
    '';
  };
}
