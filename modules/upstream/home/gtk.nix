{pkgs, ...}: {
  gtk = {
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4 = {
      # MODIFIED: removed `theme = null;` — collides with Stylix's gtk4.theme since stylix bump 2026-06 (rev e8ea85b). Let Stylix theme GTK4.
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };
  };
}
