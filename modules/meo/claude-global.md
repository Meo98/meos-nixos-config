# Globaler Kontext für Claude Code auf diesem System

Diese Datei wird von home-manager aus `~/nixos-config/modules/meo/claude-global.md`
nach `~/.claude/CLAUDE.md` verlinkt. Änderungen dort im Repo machen.

## System

- **NixOS**, Flake in `~/nixos-config` (GitHub: Meo98/meos-nixos-config). Zwei Hosts:
  `meo` (privat, NVIDIA-Laptop) und `meo-work` (Arbeit, Intel iGPU). Hostname: `hostname`.
- Desktop: **niri** (Wayland), Shell **zsh**, Home Manager ist in den Flake integriert.
- Sprache des Users: Deutsch (Schweiz). Antworte auf Deutsch, Code-Kommentare auf Deutsch.

## Regel Nr. 1: deklarativ, nicht imperativ

Alles, was dauerhaft sein soll, gehört in die Config, nicht ins laufende System:

- **Kein** `nix-env -i`, **kein** `nix profile install` für dauerhafte Tools.
  Pakete kommen in `hosts/<host>/host-packages.nix` (pro Host) bzw.
  `modules/upstream/core/packages.nix` (beide Hosts).
- **Keine** Dateien in `~/.config/` von Hand editieren, wenn Home Manager sie
  verwaltet (Symlink nach `/nix/store` = verwaltet). Dann das zugehörige
  Modul in `modules/meo/` oder `modules/upstream/home/` ändern.
- `nix shell nixpkgs#foo` / `nix run` sind fürs Ausprobieren okay.
- Ausnahme: Claude-Code-Plugins und -Marketplaces werden bewusst imperativ in
  `~/.claude/` gepflegt (siehe `modules/meo/claude-code.nix`).

## Bauen und aktivieren

- Prüfen ohne aktivieren: `nh os build --hostname <host>` (im Repo).
- Aktivieren: `fr` (Alias). Macht `git pull`, auto-commit **aller** dirty Dateien,
  `git push`, dann `nh os switch`. Also: nur fertige Änderungen im Repo lassen.
- `nh os switch` braucht sudo. Aus einer Claude-Session heraus geht das nicht
  interaktiv; dem User `fr` oder `! fr` vorschlagen.
- Vor einem Push beide Hosts dry-builden (`--hostname meo` **und** `--hostname meo-work`).
- Details, Gotchas, Troubleshooting: `~/nixos-config/CLAUDE.md` und `docs/`.

## Nix-Fakten nachschlagen statt raten

Der MCP-Server **mcp-nixos** ist aktiv (Tools `nix`, `nix_versions`). Bei
Paketnamen, Optionsnamen, Home-Manager-Optionen oder "seit welcher nixpkgs-Version
gibt es X" immer dort nachschlagen, bevor etwas in die Config geschrieben wird.
Er kennt die konkrete Config hier nicht; für lokale Werte `nix eval` verwenden,
z. B. `nix eval ~/nixos-config#nixosConfigurations.meo-work.config.<option>`.
