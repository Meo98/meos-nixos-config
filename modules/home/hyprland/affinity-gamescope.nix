{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gamescope
    (writeShellApplication {
      name = "affinity-gs";
      runtimeInputs = [ gamescope ];
      text = ''
        exec gamescope --nested -- \
          affinity-v3 wine "$HOME/.local/share/affinity-v3/drive_c/Program Files/Affinity/Affinity/Affinity.exe" --no-hw-ui
      '';
    })
  ];
}
