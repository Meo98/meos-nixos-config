{...}:
# ADDED 2026-11-12: Lernhilfen fuer nvim, die im laufenden Betrieb helfen
# (kein Tutorial, keine "alten" Tasten wie Ctrl+s). Drei Bausteine:
#
#   1. precognition.nvim — zeigt unter der Cursor-Zeile, mit welcher Taste
#      man wohin springt (w, b, e, ^, $, %), und am Rand gg/G/{/}.
#      Ein/aus: <leader>up
#   2. hardtime.nvim im Hinweis-Modus — blockiert NICHTS, meldet aber, wenn
#      es fuer das gerade Getippte einen kuerzeren Weg gibt (z.B. "jjjjj"
#      -> "5j", "$a" -> "A"). Ein/aus: <leader>uh
#   3. Spickzettel — <leader>? oeffnet ein Fenster mit den wichtigsten
#      Tasten auf Deutsch. Schliessen mit q oder Esc.
#      Text anpassen: Liste `zeilen` unten.
#
# which-key (Leertaste druecken und warten) ist schon im Upstream-Modul an.
{
  programs.nixvim = {
    plugins = {
      precognition = {
        enable = true;
        settings = {
          startVisible = true;
          # Leere Hilfszeile behalten, damit der Text beim Bewegen nicht huepft.
          showBlankVirtLine = true;
        };
      };

      hardtime = {
        enable = true;
        settings = {
          # "hint" = nur Hinweis, "block" wuerde die Taste sperren.
          restriction_mode = "hint";
          disable_mouse = false;
          # Ab so vielen Wiederholungen derselben Taste kommt der Hinweis.
          max_count = 4;
          # Pfeiltasten nicht sperren (Standard waere: gesperrt).
          disabled_keys = {
            "<Up>".__raw = "false";
            "<Down>".__raw = "false";
            "<Left>".__raw = "false";
            "<Right>".__raw = "false";
          };
        };
      };
    };

    keymaps = [
      {
        key = "<leader>?";
        mode = ["n"];
        action.__raw = "function() _G.spickzettel() end";
        options.desc = "Spickzettel (wichtigste Tasten)";
      }
      {
        key = "<leader>up";
        mode = ["n"];
        action = "<cmd>Precognition toggle<cr>";
        options.desc = "Sprung-Hinweise ein/aus (precognition)";
      }
      {
        key = "<leader>uh";
        mode = ["n"];
        action = "<cmd>Hardtime toggle<cr>";
        options.desc = "Tipp-Hinweise ein/aus (hardtime)";
      }
    ];

    extraConfigLua = ''
      -- Spickzettel: schwebendes Fenster mit den wichtigsten Tasten.
      function _G.spickzettel()
        local zeilen = {
          " SPICKZETTEL            Leertaste = <leader>     schliessen: q / Esc",
          "",
          " MODI",
          "   i / a        einfuegen vor / nach dem Cursor",
          "   o / O        neue Zeile darunter / darueber",
          "   Esc oder jk  zurueck in den Normal-Modus",
          "",
          " BEWEGEN",
          "   h j k l      links, runter, hoch, rechts",
          "   w / b / e    Wort vor / zurueck / Wortende",
          "   0 / ^ / $    Zeilenanfang / erstes Zeichen / Zeilenende",
          "   gg / G       Dateianfang / Dateiende",
          "   12G          zu Zeile 12        5j   fuenf Zeilen runter",
          "   { / }        Absatz hoch / runter",
          "   Ctrl+d / u   halbe Seite runter / hoch",
          "   /text        suchen, n / N naechster / vorheriger Treffer",
          "   f x          in der Zeile zum naechsten x springen",
          "",
          " MARKIEREN",
          "   V            ganze Zeilen (mit j / k ausdehnen)",
          "   v            zeichenweise      Ctrl+v   Block (Spalte)",
          "   viw / vip    Wort / Absatz unter dem Cursor markieren",
          "",
          " AENDERN   (wirkt auf Markierung oder zusammen mit einer Bewegung)",
          "   d / y / c    ausschneiden / kopieren / ersetzen",
          "   dd / yy      ganze Zeile ausschneiden / kopieren",
          "   p / P        einfuegen nach / vor dem Cursor",
          "   diw / ciw    Wort loeschen / ersetzen",
          "   Alt+j / k    Zeile oder Markierung runter / hoch schieben",
          "   > / <        Markierung ein- / ausruecken",
          "   u / Ctrl+r   rueckgaengig / wiederherstellen",
          "   .            letzte Aenderung wiederholen",
          "   Leer y / p   in / aus der System-Zwischenablage",
          "",
          " DATEIEN",
          "   Leer f f  oder Ctrl+p   Datei nach Namen suchen",
          "   Leer l g     in allen Dateien nach Text suchen",
          "   Leer f e     Dateibaum ein / aus",
          "   ]b / [b      naechste / vorherige offene Datei",
          "   Ctrl+6       zur zuletzt offenen Datei",
          "   :w  :wa      speichern / alle speichern",
          "   :bd  :q      Datei schliessen / Fenster schliessen",
          "   :vs datei    Datei rechts daneben, Ctrl+w h / l wechseln",
          "",
          " HILFEN",
          "   Leertaste (warten)   alle Leertaste-Kuerzel anzeigen",
          "   Leer u p     Sprung-Hinweise unter dem Cursor ein / aus",
          "   Leer u h     Tipp-Hinweise ein / aus",
        }

        local breite = 0
        for _, z in ipairs(zeilen) do
          breite = math.max(breite, vim.fn.strdisplaywidth(z))
        end
        breite = breite + 2
        local hoehe = math.min(#zeilen, vim.o.lines - 4)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, zeilen)
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = "wipe"

        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = breite,
          height = hoehe,
          row = math.floor((vim.o.lines - hoehe) / 2) - 1,
          col = math.floor((vim.o.columns - breite) / 2),
          style = "minimal",
          border = "rounded",
          title = " Spickzettel ",
          title_pos = "center",
        })
        vim.wo[win].cursorline = false

        -- Ueberschriften (Zeilen in Grossbuchstaben) hervorheben.
        for i, z in ipairs(zeilen) do
          if z:match("^ %u%u") then
            vim.api.nvim_buf_add_highlight(buf, -1, "Title", i - 1, 0, -1)
          end
        end

        for _, taste in ipairs({ "q", "<Esc>" }) do
          vim.keymap.set("n", taste, "<cmd>close<cr>", { buffer = buf, nowait = true })
        end
      end
    '';
  };
}
