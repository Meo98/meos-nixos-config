{pkgs, ...}: let
  botDir = "/home/meo/quant-trading-bot";
  binary = "${botDir}/rust/target/release/matrix_quant_core";
in {
  systemd.user.services.matrix-quant = {
    Unit = {
      Description = "Matrix Quant Trading Bot";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "${botDir}/rust";
      ExecStart = "${binary}";
      Restart = "on-failure";
      RestartSec = "30s";
      Environment = [
        "RUST_LOG=info"
        "PATH=${pkgs.coreutils}/bin:${pkgs.curl}/bin"
      ];
      StandardOutput = "append:/tmp/matrix_quant.log";
      StandardError = "append:/tmp/matrix_quant.log";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
