{pkgs, ...}: let
  # ADDED 2026-10-22: ArtCraft-Versionen folgen Latest (siehe artcraft.nix).
  artcraftUpdate = import ./scripts/artcraft-update.nix {inherit pkgs;};

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
    runtimeInputs = (with pkgs; [git nix jq coreutils diffutils libnotify]) ++ [artcraftUpdate];
    text = ''
      set -uo pipefail

      REPO="$HOME/nixos-config"
      CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/nixos-config-prewarm"
      SCRATCH="$CACHE/repo"
      LOG="$CACHE/last-build.log"
      # MODIFIED 2026-11-23: geprueftes Ergebnis fuer `fu` (siehe zsh/default.nix)
      OKLOCK="$CACHE/flake.lock.ok"   # Lock, die auf ALLEN Hosts evaluiert
      OKBASE="$CACHE/flake.lock.base" # sha256 der Repo-Lock, auf der sie aufsetzt
      HELD="$CACHE/held-back"         # zurueckgehaltene Inputs (eine Zeile je Input)
      host="$(hostname)"
      mkdir -p "$CACHE"
      : >"$LOG"

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
      git -C "$SCRATCH" checkout --quiet -- . 2>/dev/null || true
      rm -f "$OKLOCK" "$OKBASE" "$HELD"
      base="$(sha256sum "$SCRATCH/flake.lock" | cut -d' ' -f1)"
      cp "$SCRATCH/flake.lock" "$CACHE/flake.lock.alt"

      # Alle echten Hosts (ohne *-ci) — die Lock wird von `fu` gepusht und
      # muss deshalb auch auf dem jeweils anderen Laptop evaluieren.
      hosts="$(nix eval --json "$SCRATCH#nixosConfigurations" --apply builtins.attrNames 2>>"$LOG" \
        | jq -r '.[] | select(endswith("-ci") | not)')"
      [ -n "$hosts" ] || hosts="$host"

      # Evaluieren (ohne Bauen) aller Hosts: faengt die typischen Upstream-
      # Brueche ab (entfernte Optionen, Assertions, fehlende Pakete), dauert
      # pro Host ~1 min statt Stunden.
      evalok() {
        local h
        for h in $hosts; do
          nix eval --raw "$SCRATCH#nixosConfigurations.$h.config.system.build.toplevel.drvPath" \
            >/dev/null 2>>"$LOG" || { echo "  ✗ eval $h" >>"$LOG"; return 1; }
        done
      }

      # --- 1. Versuch: alles auf einmal aktualisieren ------------------------
      echo "== nix flake update (alle Inputs)" >>"$LOG"
      nix flake update --flake "$SCRATCH" >>"$LOG" 2>&1 || true
      held=""
      if ! evalok; then
        # --- 2. Versuch: Input fuer Input, kaputte zurueckhalten -------------
        # Ein einzelner kaputter Input (z.B. home-manager entfernt eine Option,
        # die Stylix noch setzt) soll nicht alle anderen Updates blockieren.
        echo "== Komplett-Update evaluiert nicht -> Input fuer Input" >>"$LOG"
        cp "$CACHE/flake.lock.alt" "$SCRATCH/flake.lock"
        for inp in $(jq -r '.nodes.root.inputs | keys[]' "$SCRATCH/flake.lock"); do
          cp "$SCRATCH/flake.lock" "$CACHE/flake.lock.vorher"
          nix flake update "$inp" --flake "$SCRATCH" >>"$LOG" 2>&1 || true
          cmp -s "$SCRATCH/flake.lock" "$CACHE/flake.lock.vorher" && continue # nichts Neues
          echo "== teste $inp" >>"$LOG"
          if ! evalok; then
            echo "  -> $inp zurueckgehalten" >>"$LOG"
            cp "$CACHE/flake.lock.vorher" "$SCRATCH/flake.lock"
            held="$held $inp"
          fi
        done
        held="''${held# }"
      fi

      # ArtCraft-Apps auf Latest heben (nur in der Scratch-Kopie), damit der
      # Test genau das baut, was `fu` gleich einspielen wuerde.
      artcraft-update "$SCRATCH" >>"$LOG" 2>&1 || true

      # nixpkgs-Datum der neuen Lock ermitteln (fuer die Meldung)
      npnode="$(jq -r '.nodes.root.inputs.nixpkgs' "$SCRATCH/flake.lock" 2>/dev/null)"
      lm="$(jq -r --arg n "$npnode" '.nodes[$n].locked.lastModified // empty' "$SCRATCH/flake.lock" 2>/dev/null)"
      npdate="unbekannt"
      [ -n "$lm" ] && npdate="$(date -d "@$lm" +%Y-%m-%d 2>/dev/null || echo unbekannt)"
      heldmsg=""
      [ -n "$held" ] && heldmsg=" Zurueckgehalten (kaputt upstream): $held."

      # --- Neue Generation bauen (KEIN switch), GC-Root schuetzt das Ergebnis
      echo "== nix build $host" >>"$LOG"
      if nix build \
          "$SCRATCH#nixosConfigurations.$host.config.system.build.toplevel" \
          --out-link "$CACHE/result-$host" >>"$LOG" 2>&1; then
        # Geprueft -> fuer `fu` bereitlegen. `fu` nimmt sie nur, wenn die
        # Repo-Lock seither unveraendert ist (sonst waere es ein Downgrade).
        cp "$SCRATCH/flake.lock" "$OKLOCK"
        echo "$base" >"$OKBASE"
        if [ -n "$held" ]; then tr ' ' '\n' <<<"$held" >"$HELD"; else : >"$HELD"; fi
        note normal software-update-available "Update vorgebaut ✓" \
          "nixpkgs $npdate baut sauber auf $host.$heldmsg 'fu' aktiviert es schnell."
      else
        note critical dialog-error "Update-Build fehlgeschlagen ✗" \
          "nixpkgs $npdate wuerde bei 'fu' scheitern.$heldmsg Log: $LOG"
      fi
    '';
  };
in {
  home.packages = [prewarm artcraftUpdate];

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
