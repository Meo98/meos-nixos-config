# Die schmale Anzeige, die im Dashboard-Terminal laeuft.
#
# Breite: auf 1/12 des eDP ausgelegt (~133 px, bei Stylix-12pt rund 16 Spalten).
# Alles darf hoechstens 16 Zeichen breit sein, sonst bricht kitty um und das
# Layout zerfaellt.
#
# Datenquellen bewusst nur /proc und /sys — keine Fremdprogramme, damit die
# Anzeige nicht an einem Paket haengt, das bei einem nixpkgs-Bump wegwandert.
#
# ZWEI DINGE, DIE HIER ABSICHT SIND UND NICHT "VEREINFACHT" WERDEN DUERFEN:
#
# 1. hwmon wird ueber den name-Eintrag aufgeloest, nicht ueber eine feste
#    Nummer. coretemp lag am 2026-08-28 auf hwmon5, aber die Nummerierung
#    haengt an der Reihenfolge der Treiber-Initialisierung und wandert beim
#    naechsten Boot. Dasselbe gilt fuer die Intel-Karte: sie wird ueber die
#    PCI-Adresse gesucht, nicht als card1 angenommen.
#
# 2. Die NVIDIA-dGPU wird NICHT abgefragt, solange sie schlaeft. Ein
#    nvidia-smi-Aufruf holt sie aus D3cold und haelt sie wach — bei einem
#    Dashboard, das im Zwei-Sekunden-Takt laeuft, waere das ein dauerhaft
#    laufender 40-Watt-Chip fuer eine Prozentzahl. Deshalb zuerst
#    power/runtime_status lesen und bei "suspended" nur "zzz" anzeigen.
{pkgs}:
pkgs.writeShellApplication {
  name = "niri-dashboard";
  runtimeInputs = with pkgs; [coreutils gnugrep gnused];
  text = ''
    # Breite der Anzeige in Zeichen. Die Balken sind WIDTH-2 lang.
    WIDTH=14

    intel_pci="0000:00:02.0"
    nvidia_pci="0000:01:00.0"

    # --- Quellen einmalig aufloesen ----------------------------------------
    # Siehe Kopfkommentar: Nummern sind nicht stabil, Namen und PCI-Adressen
    # schon.
    find_hwmon() {
      local want="$1" d
      for d in /sys/class/hwmon/hwmon*; do
        [ -r "$d/name" ] || continue
        if [ "$(cat "$d/name")" = "$want" ] && [ -r "$d/temp1_input" ]; then
          printf '%s\n' "$d/temp1_input"
          return
        fi
      done
    }

    temp_file=$(find_hwmon coretemp)
    [ -n "''${temp_file:-}" ] || temp_file=$(find_hwmon acpitz)

    igpu_dir=""
    for d in /sys/bus/pci/devices/"$intel_pci"/drm/card*; do
      [ -d "$d" ] || continue
      igpu_dir="$d"
      break
    done

    bat_dir=""
    for d in /sys/class/power_supply/BAT*; do
      [ -d "$d" ] || continue
      bat_dir="$d"
      break
    done

    # --- Bausteine ----------------------------------------------------------

    # Balken aus Vollblock und leichtem Schatten. $1 = Prozent 0..100
    bar() {
      local pct="$1" len=$((WIDTH - 2)) filled i out=""
      [ "$pct" -lt 0 ] && pct=0
      [ "$pct" -gt 100 ] && pct=100
      filled=$(( (pct * len + 50) / 100 ))
      for ((i = 0; i < len; i++)); do
        if [ "$i" -lt "$filled" ]; then out="$out█"; else out="$out░"; fi
      done
      printf '%s' "$out"
    }

    # CPU-Auslastung als Delta zweier /proc/stat-Messungen. Ein einzelner
    # Blick auf /proc/stat liefert nur Summen seit dem Boot und waere damit
    # ein Durchschnitt ueber Tage — unbrauchbar. Deshalb Zustand mitfuehren.
    prev_idle=0
    prev_total=0
    cpu_pct() {
      local line cols idle total diff_idle diff_total pct
      read -r line < /proc/stat
      # shellcheck disable=SC2206
      cols=($line)
      idle=''${cols[4]}
      total=0
      for v in "''${cols[@]:1}"; do total=$((total + v)); done
      diff_idle=$((idle - prev_idle))
      diff_total=$((total - prev_total))
      prev_idle=$idle
      prev_total=$total
      if [ "$diff_total" -le 0 ]; then printf '0\n'; return; fi
      pct=$(( (100 * (diff_total - diff_idle) + diff_total / 2) / diff_total ))
      printf '%s\n' "$pct"
    }

    mem_pct() {
      local total avail
      total=$(grep -m1 '^MemTotal:'     /proc/meminfo | tr -dc '0-9')
      avail=$(grep -m1 '^MemAvailable:' /proc/meminfo | tr -dc '0-9')
      if [ -z "$total" ] || [ "$total" -eq 0 ]; then printf '0\n'; return; fi
      printf '%s\n' $(( (100 * (total - avail) + total / 2) / total ))
    }

    # Kein echter Auslastungswert: die i915-PMU braucht dafuer erhoehte
    # Rechte. Die aktuelle Frequenz gegen die maximale ist ein brauchbarer
    # Naeherungswert und kostet nichts.
    #
    # NICHT auf gt_cur_freq_mhz umstellen. gt_act ist die TATSAECHLICHE
    # Frequenz und faellt im Leerlauf auf 0, weil die GPU in RC6 abschaltet —
    # eine 0 ist hier also richtig und kein Auslesefehler. gt_cur ist die
    # ANGEFORDERTE Frequenz und stand am 2026-08-28 bei 1300, waehrend gt_act
    # 0 war; die Anzeige haette dann dauerhaft ~55 % gemeldet.
    igpu_pct() {
      local act max
      [ -n "$igpu_dir" ] || { printf '\n'; return; }
      act=$(cat "$igpu_dir/gt_act_freq_mhz" 2>/dev/null || echo "")
      max=$(cat "$igpu_dir/gt_max_freq_mhz" 2>/dev/null || echo "")
      if [ -z "$act" ] || [ -z "$max" ] || [ "$max" -eq 0 ]; then printf '\n'; return; fi
      printf '%s\n' $(( (100 * act + max / 2) / max ))
    }

    # Siehe Kopfkommentar Punkt 2: schlafende dGPU bleibt schlafend.
    dgpu_state() {
      local st
      st=$(cat "/sys/bus/pci/devices/$nvidia_pci/power/runtime_status" 2>/dev/null || echo "")
      case "$st" in
        suspended) printf 'zzz\n' ;;
        active)    printf 'wach\n' ;;
        *)         printf '?\n' ;;
      esac
    }

    temp_c() {
      local raw
      [ -n "''${temp_file:-}" ] || { printf '\n'; return; }
      raw=$(cat "$temp_file" 2>/dev/null || echo "")
      [ -n "$raw" ] || { printf '\n'; return; }
      printf '%s\n' $((raw / 1000))
    }

    bat_pct() {
      [ -n "$bat_dir" ] || { printf '\n'; return; }
      cat "$bat_dir/capacity" 2>/dev/null || printf '\n'
    }

    bat_charging() {
      [ -n "$bat_dir" ] || return 1
      case "$(cat "$bat_dir/status" 2>/dev/null || echo)" in
        Charging|Full) return 0 ;;
        *) return 1 ;;
      esac
    }

    # --- Die Katze ----------------------------------------------------------
    # Vier Bilder: Schwanz wedelt, Augen blinzeln im dritten. Der Takt haengt
    # an der CPU-Last — bei Leerlauf doest sie, unter Volllast wedelt sie
    # schnell. Kostet nichts ausser einem Array-Index.
    cat_frame() {
      local f="$1"
      case "$f" in
        0) printf '  /\\_/\\\n ( o.o )\n  > ^ <  \n' ;;
        1) printf '  /\\_/\\\n ( o.o )\n  > ^ <~ \n' ;;
        2) printf '  /\\_/\\\n ( -.- )\n  > ^ <  \n' ;;
        *) printf '  /\\_/\\\n ( o.o )\n ~> ^ <  \n' ;;
      esac
    }

    # --- Zeichnen -----------------------------------------------------------
    # \e[?25l blendet den Cursor aus, \e[H setzt nach links oben. Neu
    # gezeichnet wird ueber die alte Ausgabe, ohne clear — sonst flackert es.
    cleanup() { printf '\e[?25h\e[2J\e[H'; }
    trap cleanup EXIT INT TERM

    printf '\e[?25l\e[2J'

    cpu_pct >/dev/null   # erste Messung verwerfen, sie hat noch kein Delta

    tick=0
    cpu=0; mem=0; igpu=""; dgpu="?"; tmp=""; bat=""
    while :; do
      # Werte alle 4 Ticks (= 2 s) neu holen, die Katze laeuft mit jedem Tick.
      if [ $((tick % 4)) -eq 0 ]; then
        cpu=$(cpu_pct)
        mem=$(mem_pct)
        igpu=$(igpu_pct)
        dgpu=$(dgpu_state)
        tmp=$(temp_c)
        bat=$(bat_pct)
      fi

      # Katzentakt: bei 0 % jeder 4. Tick, bei 100 % jeder Tick.
      speed=$(( 4 - (cpu * 3 / 100) ))
      [ "$speed" -lt 1 ] && speed=1
      frame=$(( (tick / speed) % 4 ))

      {
        printf '\e[H'
        printf '\e[1m %s\e[0m       \n' "$(date '+%H:%M:%S')"
        printf ' %-14s\n' "$(date '+%a %d.%m.')"
        printf '               \n'

        printf ' CPU %10s\n' "''${cpu}%"
        printf ' %s\n' "$(bar "$cpu")"
        printf ' RAM %10s\n' "''${mem}%"
        printf ' %s\n' "$(bar "$mem")"

        if [ -n "$igpu" ]; then
          printf ' iGPU %9s\n' "''${igpu}%"
          printf ' %s\n' "$(bar "$igpu")"
        else
          printf '               \n               \n'
        fi

        printf ' dGPU %9s\n' "$dgpu"
        printf '               \n'

        if [ -n "$tmp" ]; then
          printf ' TMP %10s\n' "''${tmp}°C"
        else
          printf '               \n'
        fi

        if [ -n "$bat" ]; then
          if bat_charging; then
            printf ' AKK %10s\n' "⚡''${bat}%"
          else
            printf ' AKK %10s\n' "''${bat}%"
          fi
          printf ' %s\n' "$(bar "$bat")"
        else
          printf '               \n               \n'
        fi

        printf '               \n'
        cat_frame "$frame"
      } 2>/dev/null

      tick=$((tick + 1))
      sleep 0.5
    done
  '';
}
