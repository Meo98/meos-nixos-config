{pkgs, ...}:
pkgs.writeShellApplication {
  name = "niri-term-toggle";
  runtimeInputs = with pkgs; [niri jq];
  text = ''
    # Ersatz fuer den pyprland-Scratchpad (Mod+Shift+T).
    #
    # niri hat kein Scratchpad und pyprland ist Hyprland-only. Stattdessen ein
    # benannter Workspace "term" (deklariert in modules/meo/niri/rules.nix),
    # auf dem per spawn-at-startup ein Ghostty mit eigener app-id liegt.
    #
    # Ein einzelner Bind kann nicht bedingt zurueckspringen, daher entscheidet
    # dieses Script anhand des gerade fokussierten Workspace.
    focused=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .name // ""')

    if [ "$focused" = "term" ]; then
      niri msg action focus-workspace-previous
    else
      niri msg action focus-workspace term
    fi
  '';
}
