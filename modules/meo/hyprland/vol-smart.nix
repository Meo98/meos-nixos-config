{ pkgs, ... }:

let
  vol-smart = pkgs.writeShellApplication {
    name = "vol-smart";
    
    # ShellCheck ignorieren, da wir pipes nutzen die er nicht mag
    excludeShellChecks = [ "SC2086" ];

    runtimeInputs = with pkgs; [
      pulseaudio
      ripgrep
      gawk
      coreutils
    ];

    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # --- Konfiguration ---
      STEP="''${2:-5%}"
      
      # Start-Lautstärke wenn man auf das Gerät wechselt
      START_RAZER="''${3:-20%}"   
      START_OTHER="''${4:-35%}"
      
      # App-Volume für "Andere" Geräte (meistens 100%, da Hardware regelt)
      INPUT_VOL_OTHER="''${5:-100%}"

      RAZER_RE='Razer|Leviathan|Levithian'
      cmd="''${1:-}"

      # --- Funktionen ---

      get_default_sink() { pactl get-default-sink 2>/dev/null || true; }

      get_sink_vol() {
        # Liest die aktuelle % Zahl des Default Sinks (nimmt den ersten Kanal/left)
        pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1
      }

      is_razer_sink() {
        local s="''${1:-}"
        local desc
        desc="$(pactl list sinks 2>/dev/null | awk -v s="$s" '
          $1=="Name:" {active = ($2==s)}
          active && $1=="Description:" {
             $1=""; sub(/^[[:space:]]+/, ""); print; exit
          }
          active && $1=="device.description" {print; exit}
        ')"
        echo "$desc" | rg -qi "$RAZER_RE"
      }

      mode_for_sink() {
        local s="''${1:-}"
        if is_razer_sink "$s"; then echo razer; else echo normal; fi
      }

      # Setzt Lautstärke für eine spezifische App-ID
      set_input_vol() {
        local id="$1"
        local vol="$2"
        pactl set-sink-input-volume "$id" "$vol" >/dev/null 2>&1 || true
      }

      # --- Hauptlogik: Synchronisation ---

      sync_volume() {
        local reason="$1"
        local cur_sink cur_mode current_hw_vol

        cur_sink="$(get_default_sink)"
        [ -z "$cur_sink" ] && return 0
        cur_mode="$(mode_for_sink "$cur_sink")"
        
        # Aktuelle Hardware-Lautstärke lesen (Das ist unser Master-Wert)
        current_hw_vol="$(get_sink_vol)"

        # Wenn wir gerade erst das Gerät gewechselt haben (Reason: switch),
        # setzen wir den Sink einmalig auf den Startwert.
        # Das Skript läuft danach nochmal durch (Reason: change), um die Inputs anzupassen.
        if [ "$reason" = "switch" ]; then
           if [ "$cur_mode" = "razer" ]; then
             pactl set-sink-volume @DEFAULT_SINK@ "$START_RAZER"
           else
             pactl set-sink-volume @DEFAULT_SINK@ "$START_OTHER"
           fi
           return
        fi

        # Apps anpassen
        if [ "$cur_mode" = "razer" ]; then
           # RAZER MODE: Alle Apps folgen sklavisch der Hardware-Lautstärke
           # Damit hast du 1:1 Mapping. 50% Sink = 50% App.
           
           # Wir iterieren über alle Inputs
           pactl list short sink-inputs 2>/dev/null | cut -f1 | while read -r id; do
             set_input_vol "$id" "$current_hw_vol"
           done

        else
           # NORMAL MODE: Apps sollen meist auf 100% stehen, Hardware regelt den Rest.
           # Oder wir lassen sie einfach in Ruhe, wenn du das lieber magst.
           # Hier setze ich sie auf 100% (INPUT_VOL_OTHER), damit es nicht leise ist.
           
           pactl list short sink-inputs 2>/dev/null | cut -f1 | while read -r id; do
             set_input_vol "$id" "$INPUT_VOL_OTHER"
           done
        fi
      }

      # --- CLI Commands ---

      case "$cmd" in
        watch)
          # Initiale Synchronisation
          sync_volume "switch"

          # Wir speichern den letzten Sink, um Wechsel zu erkennen
          last_sink="$(get_default_sink)"

          pactl subscribe | while read -r line; do
            # 1. Fall: Neuer Stream (Tab geöffnet) -> Sofort anpassen
            if echo "$line" | rg -qi "Event 'new' on sink-input"; then
               # Kleiner Sleep, damit PulseAudio das Input-Objekt fertig hat
               sleep 0.05 
               sync_volume "new_stream"
            
            # 2. Fall: Sink hat sich geändert (Lautstärke Slider bewegt)
            elif echo "$line" | rg -qi "Event 'change' on sink "; then
               # Prüfen ob es der Default Sink war ist schwierig im Shell script,
               # wir syncen einfach (kostet fast nix).
               sync_volume "vol_change"

            # 3. Fall: Anderes Gerät ausgewählt (oder Gerät weg)
            elif echo "$line" | rg -qi "Event 'new' on sink" || echo "$line" | rg -qi "Event 'remove' on sink"; then
               # Prüfen ob sich der Default Sink geändert hat
               new_sink="$(get_default_sink)"
               if [ "$new_sink" != "$last_sink" ]; then
                  last_sink="$new_sink"
                  sync_volume "switch"
               fi
            elif echo "$line" | rg -qi "Event 'change' on server"; then
               # Passiert oft beim Sink-Wechsel
               new_sink="$(get_default_sink)"
               if [ "$new_sink" != "$last_sink" ]; then
                  last_sink="$new_sink"
                  sync_volume "switch"
               fi
            fi
          done
          ;;

        # Bei manuellen Befehlen ändern wir NUR den Sink.
        # Der 'watch' Prozess im Hintergrund übernimmt dann das Syncen der Apps!
        up)
          pactl set-sink-volume @DEFAULT_SINK@ "+$STEP" >/dev/null 2>&1 || true
          ;;
        down)
          pactl set-sink-volume @DEFAULT_SINK@ "-$STEP" >/dev/null 2>&1 || true
          ;;
        mute)
          pactl set-sink-mute @DEFAULT_SINK@ toggle >/dev/null 2>&1 || true
          ;;
        
        # Manuelles Syncen erzwingen
        sync)
          sync_volume "switch"
          ;;

        *)
          echo "Usage: vol-smart {up|down|mute|sync|watch}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [ vol-smart ];

  systemd.user.services.vol-smart-watch = {
    Unit = {
      Description = "Volume Sync for Razer (Hardware follows Software)";
      After = [ "pipewire.service" "wireplumber.service" ];
    };

    Service = {
      # Parameter: CMD STEP START_RAZER START_OTHER INPUT_VOL_OTHER
      ExecStart = "${vol-smart}/bin/vol-smart watch 5% 20% 35% 100%";
      Restart = "always";
      RestartSec = 1;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
