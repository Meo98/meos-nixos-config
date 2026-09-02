{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;
    #enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-vkcapture
      obs-source-clone
      # MODIFIED 2026-09-02: OBS 32.2 deklariert obs_properties_add_button als
      # deprecated; obs-move-transition 3.2.1 (neueste Release) nutzt sie noch
      # und nixpkgs baut mit -Werror → Build bricht. Warnung wieder zulassen,
      # bis nixpkgs/upstream nachzieht — dann Override entfernen.
      (obs-move-transition.overrideAttrs (old: {
        env =
          (old.env or {})
          // {
            NIX_CFLAGS_COMPILE =
              (old.env.NIX_CFLAGS_COMPILE or "")
              + " -Wno-error=deprecated-declarations";
          };
      }))
      obs-composite-blur
      obs-backgroundremoval
    ];
  };
}
