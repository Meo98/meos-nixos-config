{
  host,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # ADDED 2026-10-16: MCP-Server fuer die ganze ArtCraft Suite
  # (modules/meo/artcraft.nix, nur meo-work). Jedes Paket liefert ein
  # `<app>-cli` mit MCP-Server auf stdio. Zwei Betriebsarten:
  #   headless   eigene Engine im CLI-Prozess (leeres Dokument, Dateien per
  #              open/save) -- funktioniert immer, idle nur 4-10 MiB RSS
  #   verbunden  haengt sich an die laufende GUI an deren Control-Port; dann
  #              sieht Claude das offene Dokument, kann Dialoge fuellen,
  #              Screenshots holen
  # Seit 2026-11-03 startet jeder GUI-Starter von selbst mit seinem Port
  # (artcraft.nix); Ports und Flags stehen in artcraft-control.nix. Der
  # Wrapper unten entscheidet BEIM START des MCP-Servers: Port offen ->
  # verbinden, sonst headless. Wird die GUI erst spaeter geoeffnet, den
  # Server in Claude Code neu verbinden (`/mcp`); nur cadcraft (--lazy)
  # verbindet von selbst.
  craftApps = import ./artcraft-control.nix;

  # `<app>-cli` ueber PATH (environment.systemPackages auf meo-work), nicht
  # als Store-Pfad: so bleibt dieses Modul auf meo ohne ArtCraft evaluierbar.
  craftMcp = name: a: let
    # Flags fuer beide Betriebsarten (z.B. --allow-path bei solidcraft).
    extra = a.mcpArgs or "";
  in
    pkgs.writeShellScript "${name}-mcp" (
      lib.optionalString (a.connect != null) ''
        # GUI laeuft mit Control-Port ${toString a.port}? Dann anbinden.
        if ${pkgs.iproute2}/bin/ss -ltnH "sport = :${toString a.port}" 2>/dev/null | grep -q . ; then
          exec ${name}-cli mcp ${a.connect} ${extra}
        fi
      ''
      + ''
        exec ${name}-cli mcp ${extra}
      ''
    );

  # ADDED 2026-11-13: solidcraft ist auf beiden Hosts installiert und soll
  # ueberall als MCP-Server da sein; die uebrigen Server bleiben wie bisher
  # auf meo-work beschraenkt.
  craftMcpApps = lib.filterAttrs (name: _: host == "meo-work" || name == "solidcraft") craftApps;
in {
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
    mcpServers =
      {
        # Aus nixpkgs-fallback: am Kanal-Kopf (2026-10-23) ist fastmcp-slim
        # broken (mcp >= 2). Siehe blockers.toml [blocker.mcp-nixos].
        nixos = {
          command = "${inputs.nixpkgs-fallback.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos}/bin/mcp-nixos";
        };
      }
      # ArtCraft Suite (siehe craftApps oben): dreizehn Server, nur auf meo-work.
      # Dazu solidcraft auf beiden Hosts (craftMcpApps).
      // lib.mapAttrs (name: a: {
        command = toString (craftMcp name a);
      })
      craftMcpApps;

    # Globales ~/.claude/CLAUDE.md -- gilt in JEDER Claude-Code-Session, egal in
    # welchem Verzeichnis. Inhalt: wo der Flake liegt, wie gebaut wird, dass
    # Aenderungen deklarativ erfolgen. Wird als Store-Symlink angelegt; Aenderungen
    # also hier im Repo machen, nicht in ~/.claude/CLAUDE.md.
    context = ./claude-global.md;

    # ADDED 2026-10-28: Skills für die Notizen in ~/Notizen (Syncthing-Ordner
    # "notizen", Struktur in ~/Notizen/Lies mich.md). Landen als
    # ~/.claude/skills/<name>/ auf beiden Hosts.
    skills = {
      notiz = builtins.readFile ./claude-skills/notiz.md;
      aufraeumen = builtins.readFile ./claude-skills/aufraeumen.md;
      verknuepfen = builtins.readFile ./claude-skills/verknuepfen.md;
    };
  };
}
