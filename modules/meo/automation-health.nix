{pkgs, ...}: let
  # Automations-Wächter — Schicht 1 (Sensor). Deterministischer Health-Check
  # der System-Automationen. Schreibt einen strukturierten Report nach
  # $XDG_STATE_HOME/automation-health/ und feuert bei Problemen notify-send.
  # Die agentische Schicht 2 (Cloud-Routine) liest diesen Report.
  # Design: docs/superpowers/specs/2026-08-20-automation-watcher-design.md
  healthCheck = pkgs.writeShellApplication {
    name = "automation-health-check";
    runtimeInputs = with pkgs; [git jq coreutils gawk systemd libnotify gh];
    text = ''
      set -uo pipefail

      REPO="$HOME/nixos-config"
      STATE="''${XDG_STATE_HOME:-$HOME/.local/state}/automation-health"
      mkdir -p "$STATE"
      host="$(hostname)"
      now="$(date +%s)"
      overall="ok"
      checks="[]"

      # add_check <id> <status ok|warn|fail|skip> <detail> <hint>
      add_check() {
        checks="$(jq -c \
          --arg id "$1" --arg st "$2" --arg d "$3" --arg h "$4" \
          '. += [{"id":$id,"status":$st,"detail":$d,"hint":$h}]' <<<"$checks")"
        case "$2" in
          fail) overall="fail" ;;
          warn) [ "$overall" != "fail" ] && overall="warn" ;;
          *) : ;;
        esac
      }

      age_days() { echo $(( (now - $1) / 86400 )); }

      # --- Check: Alter des nixpkgs-Node in flake.lock -------------------
      if [ -f "$REPO/flake.lock" ]; then
        npnode="$(jq -r '.nodes.root.inputs.nixpkgs' "$REPO/flake.lock" 2>/dev/null)"
        lm="$(jq -r --arg n "$npnode" '.nodes[$n].locked.lastModified // empty' "$REPO/flake.lock" 2>/dev/null)"
        if [ -n "$lm" ]; then
          d="$(age_days "$lm")"
          if [ "$d" -gt 21 ]; then
            add_check lock-age warn "nixpkgs ist $d Tage alt" "'fu' ausfuehren, um flake.lock zu aktualisieren"
          else
            add_check lock-age ok "nixpkgs $d Tage alt" ""
          fi
        else
          add_check lock-age skip "nixpkgs-Node nicht gefunden" ""
        fi
      else
        add_check lock-age skip "flake.lock fehlt ($REPO)" ""
      fi

      # --- Check: liegt origin/main vor local main? (Sync-Rueckstand) ----
      if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
        if git -C "$REPO" fetch --quiet origin 2>/dev/null; then
          behind="$(git -C "$REPO" rev-list --count 'main..origin/main' 2>/dev/null || echo 0)"
          if [ "''${behind:-0}" -gt 0 ]; then
            add_check git-sync warn "main ist $behind Commits hinter origin" "'fr' zieht die Aenderungen (z.B. vom anderen Host)"
          else
            add_check git-sync ok "main aktuell mit origin" ""
          fi
        else
          add_check git-sync skip "kein Netz / fetch fehlgeschlagen" ""
        fi
      else
        add_check git-sync skip "kein git-Repo" ""
      fi

      # --- Check: fehlgeschlagene systemd-Units --------------------------
      sysfailed="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd, - || true)"
      usrfailed="$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd, - || true)"
      allfailed="$(printf '%s\n%s' "$sysfailed" "$usrfailed" | grep -v '^$' | paste -sd, - || true)"
      if [ -n "$allfailed" ]; then
        add_check failed-units fail "fehlgeschlagen: $allfailed" "'systemctl status <unit>' bzw. journalctl pruefen"
      else
        add_check failed-units ok "0 fehlgeschlagene Units" ""
      fi

      # --- Check: nh-clean.timer (alleiniger GC seit 2026-08-20) ---------
      if systemctl is-active --quiet nh-clean.timer 2>/dev/null; then
        add_check gc-timer ok "nh-clean.timer aktiv" ""
      else
        add_check gc-timer warn "nh-clean.timer inaktiv" "GC laeuft nicht — programs.nh.clean pruefen"
      fi

      # --- Check: freier Platz auf / -------------------------------------
      pct="$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9' || echo 0)"
      if [ "''${pct:-0}" -ge 90 ]; then
        add_check disk-space fail "/ zu $pct% voll" "aufraeumen: 'nh clean all' / grosse Dateien pruefen"
      elif [ "''${pct:-0}" -ge 80 ]; then
        add_check disk-space warn "/ zu $pct% voll" "bald aufraeumen"
      else
        add_check disk-space ok "/ zu $pct% belegt" ""
      fi

      # --- Report schreiben ---------------------------------------------
      ts="$(date -Iseconds)"
      report="$(jq -n \
        --arg gen "$ts" --arg host "$host" --arg overall "$overall" \
        --argjson checks "$checks" \
        '{generated:$gen, host:$host, overall:$overall, checks:$checks}')"
      printf '%s\n' "$report" >"$STATE/report.json"
      {
        echo "Automation-Health $ts ($host) — GESAMT: $overall"
        jq -r '.checks[] | "  [\(.status)] \(.id): \(.detail)\(if .hint != "" then "  → \(.hint)" else "" end)"' <<<"$report"
      } >"$STATE/report.txt"
      cat "$STATE/report.txt"

      # --- Benachrichtigen bei Problemen --------------------------------
      if [ "$overall" != "ok" ]; then
        urgency="normal"; [ "$overall" = "fail" ] && urgency="critical"
        summary="$(jq -r '[.checks[] | select(.status=="warn" or .status=="fail") | .id] | join(", ")' <<<"$report")"
        notify-send -u "$urgency" -i dialog-warning \
          "Automations-Wächter: $overall" "Betroffen: $summary" 2>/dev/null || true
      fi
    '';
  };
in {
  home.packages = [healthCheck];

  systemd.user.services.automation-health-check = {
    Unit.Description = "Automations-Wächter: Health-Check der System-Automationen";
    Service = {
      Type = "oneshot";
      ExecStart = "${healthCheck}/bin/automation-health-check";
    };
  };

  systemd.user.timers.automation-health-check = {
    Unit.Description = "Timer: Automations-Wächter Health-Check";
    Timer = {
      OnCalendar = "*-*-1/3 09:00:00"; # alle 3 Tage 09:00
      Persistent = true; # verpasste Laeufe nach Standby/Aus nachholen
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = ["timers.target"];
  };
}
