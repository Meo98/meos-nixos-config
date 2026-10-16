# niri-pip — Picture-in-Picture-Regler fuer niri.
#
# Reines Rust-Workspace-Projekt mit fuenf Crates (seit v0.3.0 zusaetzlich
# niripip-ui, die lokale Settings-Anwendung hinter `niripip ui`); gebaut
# werden die Programme:
#   niripipd  der Daemon (crates/niripip-daemon)
#   niripip   die Steuerung (crates/niripip-cli)
#
# Keine Systembibliotheken noetig. Geprueft am Cargo.lock des Tags v0.3.2
# (2026-10-15; vorher v0.2.1 mit 75 Paketen): 106 Pakete, keine
# `source = "git+"`-Eintraege (sonst braeuchte es cargoLock.outputHashes)
# und ausser windows-sys kein einziges *-sys-Crate.
#
# rust-toolchain.toml des Projekts pinnt Rust 1.97.1; buildRustPackage
# ignoriert die Datei und nimmt den Compiler aus nixpkgs. Das ist in Ordnung,
# weil Cargo.toml als Untergrenze rust-version = "1.81" nennt.
{
  pkgs,
  src,
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "niri-pip";
  version = "0.3.2";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = {
    description = "Picture-in-Picture- und Sticky-Fenster-Regler fuer niri";
    homepage = "https://github.com/t1ktakdev/niri-pip";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.linux;
    mainProgram = "niripip";
  };
}
