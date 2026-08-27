# Autostart.
#
# Portiert aus modules/upstream/home/hyprland/exec-once.nix. ENTFALLEN:
#   - dbus-update-activation-environment / systemctl --user import-environment:
#     `niri --session` importiert die Umgebung selbst. Genau deshalb setzt das
#     nixpkgs-Modul enableDefaultPath = false auf der Unit.
#   - qs -c overview: Overview ist in niri eingebaut (Mod+Tab).
#   - killall waybar/swaync: unter niri startet keines von beiden.
#   - swww-daemon: Noctalia v5 macht das Wallpaper selbst (wallpaper.enabled).
#     Sollte der Hintergrund leer bleiben, ist das der erste Verdaechtige.
#
# hyprpolkitagent laeuft als systemd-User-Unit und ist compositor-unabhaengig.
# Noctalia bringt mit shell.polkit_agent = true einen eigenen mit — falls beim
# ersten Login zwei Passwortdialoge auftauchen, diese Zeile streichen.
#
# spawn-at-startup ist bei niri ein WIEDERHOLBARER Top-Level-Node (eine Zeile
# pro Programm), kein einzelner Node mit einer Liste von Kommandos. Der
# toKDL-Generator des home-manager-Moduls bildet das nur ueber
# settings._children + _args ab (genau wie workspace/output in
# outputs.nix/rules.nix) — eine direkte Liste-von-Listen unter
# settings.spawn-at-startup erzeugt ungueltiges KDL ("- ..."-Kindknoten statt
# eigener Zeilen) und faellt bei `niri validate` durch.
{...}: {
  wayland.windowManager.niri.settings = {
    _children = [
      {spawn-at-startup._args = ["wl-paste" "--type" "text" "--watch" "cliphist" "store"];}
      {spawn-at-startup._args = ["wl-paste" "--type" "image" "--watch" "cliphist" "store"];}
      {spawn-at-startup._args = ["systemctl" "--user" "start" "hyprpolkitagent"];}
      # Terminal fuer den term-Workspace; die window-rule in rules.nix
      # platziert es dort. kitty statt des sonst konfigurierten ghostty, weil
      # ghosttys gtk-single-instance = true einen zweiten Aufruf mit eigener
      # --class verschluckt (siehe Kommentar in rules.nix).
      {spawn-at-startup._args = ["kitty" "--class=kitty-dropterm"];}
    ];

    # Verzoegert, damit Stylix zuerst fertig ist und danach das Nutzer-Wallpaper
    # mit genau einem Wechsel gewinnt — gleiche Logik wie unter Hyprland.
    # Ein einzelner String ist hier (anders als spawn-at-startup) korrekt, weil
    # spawn-sh-at-startup nur einmal vorkommt.
    spawn-sh-at-startup = "sleep 2 && (qs-wallpapers-restore >/dev/null 2>&1 || true)";
  };
}
