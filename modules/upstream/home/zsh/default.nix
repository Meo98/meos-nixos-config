{
  profile,
  nixosTarget,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./zshrc-personal.nix
  ];

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = ["main" "brackets" "pattern" "regexp" "root" "line"];
    };
    historySubstringSearch.enable = true;

    history = {
      ignoreDups = true;
      save = 10000;
      size = 10000;
    };

    oh-my-zsh = {
      enable = true;
    };

    # MODIFIED 2026-06-16: dropped powerlevel10k in favor of Starship
    # (see modules/meo/cli-modern.nix). p10k-config/ directory left in place
    # as orphan and can be cleaned up later.
    plugins = [];

    initContent = ''
      bindkey "\eh" backward-word
      bindkey "\ej" down-line-or-history
      bindkey "\ek" up-line-or-history
      bindkey "\el" forward-word
      if [ -f $HOME/.zshrc-personal ]; then
        source $HOME/.zshrc-personal
      fi

      # MODIFIED: paths changed from ~/zaneyos to ~/nixos-config (2026-05-18 Clean Fork)
      # Auto-Sync: nixos-config mit GitHub synchronisieren
      _zsync() {
        echo "→ Syncing nixos-config with GitHub..."
        # Nur tracked files updaten + neue .nix/.lua/.md/.toml/.png/.jpg
        git -C ~/nixos-config add -u
        git -C ~/nixos-config ls-files --others --exclude-standard -- \
          '*.nix' '*.lua' '*.md' '*.toml' '*.png' '*.jpg' '*.jpeg' \
          | xargs -r git -C ~/nixos-config add --
        if ! git -C ~/nixos-config diff --cached --quiet; then
          git -C ~/nixos-config commit -m "chore: auto-sync from $(hostname) $(date '+%Y-%m-%d %H:%M')"
        fi
        git -C ~/nixos-config pull --rebase || { echo "✗ Git pull failed - resolve conflicts first"; return 1; }
        git -C ~/nixos-config push || { echo "✗ Git push failed"; return 1; }
        echo "✓ Sync done"
      }

      # MODIFIED: Kernel-Bump-Guard (2026-07-01). fr synct + rebuildet, updated
      # aber KEINE Inputs (kein --update). Falls der pull in _zsync dennoch
      # flake.lock aendert (z.B. ein bewusstes 'fu' vom anderen Host), steckt
      # evtl. ein neuer linuxPackages_latest-Kernel drin -> NVIDIA-Modul ist nie
      # gecacht (unfree) und muss dann lokal neu kompiliert werden (langsam).
      # Deshalb erst nachfragen, statt still einen langen Build zu starten.
      # Bewusste Kernel-/Input-Updates weiterhin via 'fu'.
      fr() {
        local before after
        before=$(git -C ~/nixos-config rev-parse HEAD:flake.lock 2>/dev/null)
        _zsync || return 1
        after=$(git -C ~/nixos-config rev-parse HEAD:flake.lock 2>/dev/null)
        if [ "$before" != "$after" ]; then
          echo "⚠ flake.lock hat sich geaendert – evtl. neuer Kernel + NVIDIA-Recompile (kann lange dauern)."
          if ! read -q "?Jetzt trotzdem rebuilden? [y/N] "; then
            echo
            echo "→ Rebuild uebersprungen. Config-Dateien sind gesynct; spaeter bewusst mit 'fr' bauen."
            return 0
          fi
          echo
        fi
        nh os switch --hostname ${nixosTarget}
      }
    '';

    shellAliases = {
      nix-fmt-all = "nix fmt ./";
      sv = "sudo nvim";
      v = "nvim";
      c = "clear";
      # fr ist jetzt eine Funktion (siehe oben, Kernel-Bump-Guard) — kein Alias mehr.
      fu = "_zsync && nh os switch --hostname ${nixosTarget} --update && _zsync";
      # Warnung: curl|sh ohne Checksum-Verifikation — nur in vertrautem Netz nutzen
      zu = ''echo "⚠ Führt Remote-Script aus – prüfe: https://gitlab.com/Zaney/zaneyos/-/releases" && read -q "?Fortfahren? [y/N] " && echo && sh <(curl -L https://gitlab.com/Zaney/zaneyos/-/releases/latest/download/install-zaneyos.sh)'';
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      cat = "bat";
      man = "batman";
    };
  };
}
