{ lib, ... }:
# Erinnerung: Stylix-Input ist temporaer auf github:-URL gepinnt statt
# git+https://-URL wie die anderen Inputs (Schutz gegen GitHub-504 beim
# /archive/<sha>.tar.gz-Endpoint).
#
# Grund: Stylix 2026-06-05 hat Breaking-Changes:
#   1. gtk.gtk4.theme = config.gtk.theme   (Konflikt mit modules/upstream/home/gtk.nix)
#   2. services.kmscon.config              (in nixpkgs umbenannt zu .extraConfig)
#
# Sobald Stylix ein neueres Release mit Fix hat: in flake.nix die URL von
#   url = "github:danth/stylix";
# umstellen auf:
#   url = "git+https://github.com/danth/stylix.git";
# und diesen Datei loeschen (sowie die imports in hosts/{meo,meo-work}/default.nix).
{
  warnings = [
    ''

      ╔══════════════════════════════════════════════════════════════════════╗
      ║  ⚠  TODO: Stylix-Input ist auf github:-URL gepinnt (temporaer)       ║
      ║                                                                      ║
      ║  Workaround wegen Breaking-Changes in Stylix 2026-06-05.             ║
      ║  Bei naechstem Stylix-Release auf git+https://-URL umstellen.        ║
      ║  Details: modules/meo/stylix-pin-warning.nix                         ║
      ╚══════════════════════════════════════════════════════════════════════╝
    ''
  ];
}
