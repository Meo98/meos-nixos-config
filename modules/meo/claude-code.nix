{ pkgs, ... }:
{
  # Claude Code: deklarative Teile der Konfiguration. ADDED 2026-10-12
  #
  # Das Binary selbst kommt systemweit aus hosts/*/host-packages.nix
  # (environment.systemPackages), deshalb `package = null` -- sonst wuerde
  # home-manager ein zweites `claude` nach ~/.nix-profile legen.
  #
  # BEWUSST NICHT gesetzt: `settings`, `marketplaces`, `plugins`.
  # Sobald eines davon gesetzt ist, legt das Modul ~/.claude/settings.json als
  # read-only Store-Symlink an und die imperativ installierten Plugins/
  # Marketplaces (`/plugin install ...`) waeren nicht mehr pflegbar. Die
  # Plugin-Verwaltung bleibt daher absichtlich imperativ in ~/.claude/.
  #
  # Mechanik: home-manager erzeugt ein "persoenliches Plugin" unter
  # ~/.claude/skills/claude-code-home-manager mit einer .mcp.json. Die
  # MCP-Tools heissen dadurch mcp__plugin_hm_nixos__<tool>.
  programs.claude-code = {
    enable = true;
    package = null;

    # mcp-nixos (utensils): Live-Suche in nixpkgs-Paketen, NixOS-/Home-Manager-/
    # nix-darwin-Optionen und Paket-Versionshistorie (Tools: `nix`, `nix_versions`).
    # Fragt search.nixos.org & Co. ab -- braucht Netz, kennt aber NICHT diese
    # konkrete Config (dafuer ist ~/.claude/CLAUDE.md bzw. das Repo-CLAUDE.md da).
    mcpServers.nixos = {
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };

    # Globales ~/.claude/CLAUDE.md -- gilt in JEDER Claude-Code-Session, egal in
    # welchem Verzeichnis. Inhalt: wo der Flake liegt, wie gebaut wird, dass
    # Aenderungen deklarativ erfolgen. Wird als Store-Symlink angelegt; Aenderungen
    # also hier im Repo machen, nicht in ~/.claude/CLAUDE.md.
    context = ./claude-global.md;
  };
}
