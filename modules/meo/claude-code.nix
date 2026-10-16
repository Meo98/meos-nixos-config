{
  host,
  lib,
  pkgs,
  ...
}: let
  # ADDED 2026-10-16: MCP-Server fuer die ganze ArtCraft Suite
  # (modules/meo/artcraft.nix, nur meo-work). Jedes Paket liefert ein
  # `<app>-cli` mit MCP-Server auf stdio. Zwei Betriebsarten:
  #   headless   eigene Engine im CLI-Prozess (leeres Dokument, Dateien per
  #              open/save) -- funktioniert immer, idle nur 4-10 MiB RSS
  #   verbunden  haengt sich an die laufende GUI, wenn diese mit
  #              `<app> --control <port>` gestartet wurde; dann sieht Claude
  #              das offene Dokument, kann Dialoge fuellen, Screenshots holen
  # Die CLIs unterscheiden sich in der Flag-Syntax (--connect PORT,
  # --connect HOST:PORT, --bridge ...) und darin, was ohne laufende App
  # passiert: vectorcraft/designcraft/wordcraft/gridcraft brechen sofort ab
  # (Claude Code meldet dann "failed to connect"), andere fallen selbst auf
  # headless zurueck. Der Wrapper unten vereinheitlicht das: Port offen ->
  # verbinden, sonst headless. Ports pro App eindeutig, damit mehrere Apps
  # gleichzeitig steuerbar sind (designcraft behaelt das Upstream-Beispiel
  # 7979). Startbefehl fuer den verbundenen Modus steht je App als `launch`.
  # Alle Control-Ports sind loopback-only und ohne Auth (ausser photocraft:
  # Bearer-Token-Datei, die GUI legt sie beim ersten Start mit 0600 an).
  # Verifiziert 2026-10-16 gegen die Versionen in artcraft.nix.
  craftApps = {
    photocraft = {
      connect = "--bridge 127.0.0.1:7971 --control-token-file \"$HOME/.config/photocraft/control.token\"";
      port = 7971;
      launch = "photocraft --control 7971 --control-token-file ~/.config/photocraft/control.token";
    };
    vectorcraft = {
      connect = "--connect 127.0.0.1:7972";
      port = 7972;
      launch = "vectorcraft --control 7972";
    };
    designcraft = {
      connect = "--connect 7979";
      port = 7979;
      launch = "designcraft --control 7979";
    };
    lightcraft = {
      connect = "--connect 127.0.0.1:7973";
      port = 7973;
      launch = "lightcraft --control 7973";
    };
    filmcraft = {
      connect = "--bridge 127.0.0.1:7974";
      port = 7974;
      launch = "filmcraft --control 7974";
    };
    effectcraft = {
      connect = "--bridge 7975";
      port = 7975;
      launch = "effectcraft --control 7975";
    };
    # pdfcraft: GUI-Steuerung nur ueber eine Socket-DATEI (`pdfcraft --control
    # FILE`, `pdfcraft-cli ui --control FILE`), der MCP-Server kennt keinen
    # Bridge-Modus -> nur headless.
    pdfcraft = {connect = null;};
    wordcraft = {
      connect = "--connect 127.0.0.1:7977";
      port = 7977;
      launch = "wordcraft --control 7977";
    };
    gridcraft = {
      connect = "--connect 7978";
      port = 7978;
      launch = "gridcraft --control 7978";
    };
    # deckcraft 0.7.0: GUI kennt kein --control -> nur headless.
    deckcraft = {connect = null;};
    soundcraft = {
      connect = "--connect 7981";
      port = 7981;
      launch = "soundcraft --control 7981";
    };
    cadcraft = {
      # --lazy: verbindet erst beim ersten Aufruf, bricht also auch dann
      # nicht ab, wenn die App spaeter startet.
      connect = "--connect 127.0.0.1:7982 --lazy";
      port = 7982;
      launch = "cadcraft --control 7982";
    };
  };

  # `<app>-cli` ueber PATH (environment.systemPackages auf meo-work), nicht
  # als Store-Pfad: so bleibt dieses Modul auf meo ohne ArtCraft evaluierbar.
  craftMcp = name: a:
    pkgs.writeShellScript "${name}-mcp" (
      lib.optionalString (a.connect != null) ''
        # GUI laeuft mit Control-Port (${a.launch})? Dann anbinden.
        if ${pkgs.iproute2}/bin/ss -ltnH "sport = :${toString a.port}" 2>/dev/null | grep -q . ; then
          exec ${name}-cli mcp ${a.connect}
        fi
      ''
      + ''
        exec ${name}-cli mcp
      ''
    );
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
        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        };
      }
      # ArtCraft Suite (siehe craftApps oben): zwoelf Server, nur auf meo-work.
      // lib.optionalAttrs (host == "meo-work") (lib.mapAttrs (name: a: {
          command = toString (craftMcp name a);
        })
        craftApps);

    # Globales ~/.claude/CLAUDE.md -- gilt in JEDER Claude-Code-Session, egal in
    # welchem Verzeichnis. Inhalt: wo der Flake liegt, wie gebaut wird, dass
    # Aenderungen deklarativ erfolgen. Wird als Store-Symlink angelegt; Aenderungen
    # also hier im Repo machen, nicht in ~/.claude/CLAUDE.md.
    context = ./claude-global.md;
  };
}
