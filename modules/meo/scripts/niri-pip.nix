# niri-pip — Picture-in-Picture-Regler fuer niri.
#
# Reines Rust-Workspace-Projekt mit vier Crates; gebaut werden zwei Programme:
#   niripipd  der Daemon (crates/niripip-daemon)
#   niripip   die Steuerung (crates/niripip-cli)
#
# Keine Systembibliotheken noetig. Geprueft am Cargo.lock des Tags v0.2.1:
# 75 Pakete, keine `source = "git+"`-Eintraege (sonst braeuchte es
# cargoLock.outputHashes) und ausser windows-sys kein einziges *-sys-Crate.
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
  version = "0.2.1";
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
