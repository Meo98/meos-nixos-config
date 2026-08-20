{pkgs, ...}: let
  # Prio 1 — Update-Pre-warm (lokal-first). Baut nachts die NEUE Generation
  # (mit frischer flake.lock) OHNE zu switchen, und benachrichtigt:
  #   Erfolg → "Update baut sauber, 'fu' aktiviert es schnell (vorgebaut)."
  #   Fehler → "Update-Build wuerde scheitern — 'fu' jetzt nicht ausfuehren."
  # So ist der teure Kernel/NVIDIA-Recompile schon erledigt und gecacht, wenn
  # du 'fu' laeufst — und du weisst vorher, ob der Bump ueberhaupt baut.
  # Arbeitet in einer ISOLIERTEN Scratch-Kopie: fasst die echte flake.lock
  # NIE an (die wuerde 'fr' sonst committen/pushen). Kein switch, kein push.
  prewarm = pkgs.writeShellApplication {
    name = "update-prewarm";
    runtimeInputs = with pkgs; [git nix jq coreutils libnotify];
    text = ''
      set -uo pipefail

      REPO="$HOME/nixos-config"
      CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/nixos-config-prewarm"
      SCRATCH="$CACHE/repo"
      LOG="$CACHE/last-build.log"
      host="$(hostname)"
      mkdir -p "$CACHE"

      note() { notify-send -u "$1" -i "$2" "$3" "$4" 2>/dev/null || true; }

      # --- Scratch-Klon auf den Stand des lokalen committeten main bringen ---
      if [ ! -d "$SCRATCH/.git" ]; then
        git clone --quiet --shared "$REPO" "$SCRATCH" || {
          note critical dialog-error "Pre-warm" "git clone fehlgeschlagen"; exit 1; }
      fi
      # HEAD des echten Repos holen (committeter Stand; uncommitted WIP ausgespart)
      git -C "$SCRATCH" fetch --quiet "$REPO" HEAD 2>/dev/null || true
      git -C "$SCRATCH" reset --hard --quiet FETCH_HEAD 2>/dev/null \
        || git -C "$SCRATCH" reset --hard --quiet HEAD

      # --- flake.lock in der Scratch-Kopie aktualisieren --------------------
      if ! git -C "$SCRATCH" diff --quiet 2>/dev/null; then
        git -C "$SCRATCH" checkout --quiet -- . 2>/dev/null || true
      fi
      nix flake update --flake "$SCRATCH" >>"$LOG" 2>&1 || true

      # nixpkgs-Datum der neuen Lock ermitteln (fuer die Meldung)
      npnode="$(jq -r '.nodes.root.inputs.nixpkgs' "$SCRATCH/flake.lock" 2>/dev/null)"
      lm="$(jq -r --arg n "$npnode" '.nodes[$n].locked.lastModified // empty' "$SCRATCH/flake.lock" 2>/dev/null)"
      npdate="unbekannt"
      [ -n "$lm" ] && npdate="$(date -d "@$lm" +%Y-%m-%d 2>/dev/null || echo unbekannt)"

      # --- Neue Generation bauen (KEIN switch), GC-Root schuetzt das Ergebnis
      : >"$LOG"
      if nix build \
          "$SCRATCH#nixosConfigurations.$host.config.system.build.toplevel" \
          --out-link "$CACHE/result-$host" >>"$LOG" 2>&1; then
        note normal software-update-available "Update vorgebaut ✓" \
          "nixpkgs $npdate baut sauber auf $host. 'fu' aktiviert es schnell."
      else
        note critical dialog-error "Update-Build fehlgeschlagen ✗" \
          "nixpkgs $npdate wuerde bei 'fu' scheitern. Log: $LOG"
      fi
    '';
  };
in {
  home.packages = [prewarm];

  systemd.user.services.update-prewarm = {
    Unit = {
      Description = "Update-Pre-warm: neue NixOS-Generation vorbauen (kein switch)";
      # Nur auf Netzstrom bauen — schont den Akku (langer NVIDIA/Kernel-Build).
      ConditionACPower = true;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${prewarm}/bin/update-prewarm";
      # Ressourcenschonend: niedrige CPU/IO-Prioritaet
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.update-prewarm = {
    Unit.Description = "Timer: Update-Pre-warm (nachts, nur auf Netzstrom)";
    Timer = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true; # verpasste Laeufe (Laptop war aus) nachholen
      RandomizedDelaySec = "45m";
    };
    Install.WantedBy = ["timers.target"];
  };
}
