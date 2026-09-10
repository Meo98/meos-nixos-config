{ config, ... }:
let
  home = config.home.homeDirectory;
in
{
  # PATH fuer Claude-Code-Werkzeuge, die NICHT aus nixpkgs kommen und deshalb
  # imperativ im Home liegen. Die zugehoerigen Plugin-Hooks rufen die Binaries
  # blank auf (`headroom init hook ensure`, `command -v rtk`) -- ohne PATH-
  # Eintrag warnen sie nur und steigen aus, das Plugin bleibt wirkungslos.
  #
  #   ~/.local/bin   headroom   (uv tool install "headroom-ai[all]")
  #   ~/.cargo/bin   rtk        (cargo install --git https://github.com/rtk-ai/rtk)
  #                             ACHTUNG: das Crate `rtk` auf crates.io ist ein
  #                             ANDERES Projekt (Rust Type Kit). Probe: `rtk gain`
  #                             muss existieren. Laufzeit-Libs sind per GC-Root
  #                             in ~/.cache/nix-gcroots gehalten.
  #   ~/.bun/bin     omniroute  (bun install -g omniroute)
  home.sessionPath = [
    "${home}/.local/bin"
    "${home}/.cargo/bin"
    "${home}/.bun/bin"
  ];

  # Ohne das legt bun global nach ~/.cache/.bun/bin -- ein Cache-Verzeichnis,
  # das jeder Aufraeumlauf leeren darf.
  home.sessionVariables.BUN_INSTALL = "${home}/.bun";
}
