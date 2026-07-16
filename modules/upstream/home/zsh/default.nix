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
      # MODIFIED 2026-07-16: Build-first-Umbau. Vorher pushte _zsync ungetestete
      # Aenderungen zu GitHub BEVOR gebaut wurde -> kaputte Configs/Locks landeten
      # auf main und der jeweils andere Host (meo: Trading-Bot!) zog sie beim
      # naechsten fr. Neu: erst pull, dann BUILD, und erst bei gruenem Build
      # committen/pushen/switchen. Commit-Message ist abfragbar (Enter = auto).

      # Commit + Push lokale Aenderungen — NUR nach erfolgreichem Build aufrufen.
      _zpush() {
        # Nur tracked files updaten + neue .nix/.lua/.md/.toml/.png/.jpg
        git -C ~/nixos-config add -u
        git -C ~/nixos-config ls-files --others --exclude-standard -- \
          '*.nix' '*.lua' '*.md' '*.toml' '*.png' '*.jpg' '*.jpeg' \
          | xargs -r git -C ~/nixos-config add --
        if ! git -C ~/nixos-config diff --cached --quiet; then
          local files msg
          files=$(git -C ~/nixos-config diff --cached --name-only | head -5 | tr '\n' ' ')
          read -r "msg?→ Commit-Message (Enter = auto-sync): "
          [ -z "$msg" ] && msg="chore: sync from $(hostname) $(date '+%Y-%m-%d %H:%M') — $files"
          git -C ~/nixos-config commit -m "$msg"
        fi
        git -C ~/nixos-config push || { echo "✗ Git push failed"; return 1; }
        echo "✓ Sync done"
      }

      # fr: pull -> BUILD -> erst bei Erfolg commit+push+switch.
      # Kernel-Bump-Guard (2026-07-01) bleibt: bringt der pull eine neue
      # flake.lock (z.B. gemergter Update-PR), steckt evtl. ein neuer Kernel
      # drin -> NVIDIA-Modul (unfree, nie gecacht) muss lokal kompilieren.
      # Deshalb nachfragen statt still einen langen Build zu starten.
      fr() {
        local before after
        before=$(git -C ~/nixos-config rev-parse HEAD:flake.lock 2>/dev/null)
        echo "→ Pulling nixos-config..."
        git -C ~/nixos-config pull --rebase --autostash || { echo "✗ Git pull failed - resolve conflicts first"; return 1; }
        after=$(git -C ~/nixos-config rev-parse HEAD:flake.lock 2>/dev/null)
        if [ "$before" != "$after" ]; then
          echo "⚠ flake.lock hat sich geaendert – evtl. neuer Kernel + NVIDIA-Recompile (kann lange dauern)."
          if ! read -q "?Jetzt bauen? [y/N] "; then
            echo
            echo "→ Abgebrochen. Lokale Aenderungen sind NICHT gesynct (erst nach gruenem Build)."
            return 0
          fi
          echo
        fi
        echo "→ Building (nichts wird gepusht/aktiviert, bevor das grün ist)..."
        if ! nh os build --hostname ${nixosTarget}; then
          echo "✗ Build fehlgeschlagen — NICHTS committed, gepusht oder aktiviert."
          return 1
        fi
        _zpush || return 1
        nh os switch --hostname ${nixosTarget}
      }

      # fu: flake update -> BUILD -> gruen: commit+push+switch / rot: Lock-Rollback.
      # Ungetestete Input-Bumps erreichen so weder GitHub noch das Live-System.
      # Alternative ohne lokales Bauen: den woechentlichen CI-Update-PR
      # (flake-update.yml) mergen, wenn build.yml beide Hosts gruen zeigt.
      fu() {
        echo "→ Pulling nixos-config..."
        git -C ~/nixos-config pull --rebase --autostash || { echo "✗ Git pull failed"; return 1; }
        echo "→ nix flake update..."
        (cd ~/nixos-config && nix flake update) || return 1
        echo "→ Building mit neuer flake.lock (Update zaehlt erst bei Erfolg)..."
        if ! nh os build --hostname ${nixosTarget}; then
          echo "✗ Build mit neuen Inputs fehlgeschlagen — flake.lock wird zurueckgerollt."
          git -C ~/nixos-config checkout HEAD -- flake.lock
          echo "→ Rollback done. System und GitHub unveraendert."
          return 1
        fi
        _zpush || return 1
        nh os switch --hostname ${nixosTarget}
      }
    '';

    shellAliases = {
      nix-fmt-all = "nix fmt ./";
      sv = "sudo nvim";
      v = "nvim";
      c = "clear";
      # MODIFIED 2026-07-16: fr UND fu sind jetzt Funktionen (build-first, siehe
      # oben) — Aliases entfernt, sonst wuerden sie die Funktionen ueberschatten.
      # zu-Alias (curl|sh zaneyos-Installer) entfernt: Altlast, wir sind ein
      # Clean Fork ohne zaneyos-Upstream-Beziehung.
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      cat = "bat";
      man = "batman";
    };
  };
}
