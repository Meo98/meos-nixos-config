# yazi.toml – nur die Abweichungen von den yazi-Standardwerten.
#
# MODIFIED 2026-11-19: Diese Datei war früher eine vollständige Kopie der
# Standardwerte, eingepackt in `{ settings = { … }; }`. Dadurch landete alles
# unter `[settings.*]` in der yazi.toml und yazi hat die ganze Datei ignoriert
# (keine Datumsspalte, kein git-Status, keine Archiv-Vorschau). Jetzt stehen
# die Abschnitte direkt auf oberster Ebene, mit den Namen von yazi 26.x
# (`mgr` statt `manager`, `url` statt `name`). Alles, was hier nicht steht,
# kommt aus den eingebauten Standardwerten von yazi.
{
  mgr = {
    ratio = [1 4 3];
    sort_by = "natural"; # «Datei 2» vor «Datei 10», wie im Windows-Explorer
    sort_sensitive = false;
    sort_dir_first = true;
    # Spalte rechts neben dem Dateinamen: Grösse + Änderungsdatum.
    # Die Funktion dazu steht in default.nix (initLua, Linemode:groesse_datum).
    linemode = "groesse_datum";
    show_hidden = false;
    show_symlink = true;
    scrolloff = 5;
  };

  opener = {
    markdown = [
      {
        run = "glow -p %s1";
        block = true;
        desc = "Preview with glow";
        for = "unix";
      }
    ];
  };

  open = {
    # edit zuerst (-> nvim mit render-markdown), markdown (glow) als 2. Option
    # für die reine Lese-Ansicht. Siehe modules/meo/nvim-yazi-tweaks.nix
    prepend_rules = [
      {
        url = "*.{md,markdown}";
        use = ["edit" "markdown" "reveal"];
      }
      # MODIFIED 2026-11-24: HTML im O-Menü auch im Browser öffnen ("open" =
      # eingebauter Öffner, xdg-open). Enter bleibt beim Editor.
      {
        url = "*.{html,htm}";
        use = ["edit" "open" "reveal"];
      }
    ];
  };

  plugin = {
    prepend_previewers = [
      {
        url = "*.{md,markdown}";
        run = "glow";
      }
      # Archiv-Inhalt als Vorschau (ouch-Plugin).
      {
        mime = "application/{*zip,tar,bzip2,7z*,rar,xz,zstd,java-archive}";
        run = "ouch";
      }
    ];
    # git-Status (geändert/neu/ignoriert) als Zeichen neben dem Dateinamen.
    prepend_fetchers = [
      {
        url = "*";
        run = "git";
        group = "git";
      }
      {
        url = "*/";
        run = "git";
        group = "git";
      }
    ];
  };
}
