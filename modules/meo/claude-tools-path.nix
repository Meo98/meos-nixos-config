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
  #   ~/.local/bin   headroom   ALTLAST (uv tool install "headroom-ai[all]")
  #   ~/.cargo/bin   rtk        ALTLAST (cargo install --git .../rtk-ai/rtk,
  #                             GC-Root in ~/.cache/nix-gcroots)
  #
  # Seit 2026-11-27 kommen rtk und headroom aus nixpkgs
  # (modules/upstream/core/packages.nix). Noch vorhandene Altlast-Binaries in
  # ~/.cargo/bin bzw. ~/.local/bin stehen im PATH DAVOR und gewinnen, bis sie
  # geloescht sind (`cargo uninstall rtk`, `uv tool uninstall headroom-ai`).
  # Probe fuers richtige rtk: `rtk gain` muss existieren (das Crate `rtk` auf
  # crates.io ist ein anderes Projekt).
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
