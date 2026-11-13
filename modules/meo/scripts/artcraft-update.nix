{pkgs}:
# ADDED 2026-10-22: Haelt modules/meo/artcraft-versions.json auf dem neuesten
# GitHub-Release jeder ArtCraft-App (github.com/storytold/<app>).
# Eintraege mit Feld "owner" kommen von einem anderen GitHub-Konto
# (solidcraft: tangency-labs); das Feld bleibt beim Update erhalten.
#
# Pro App: releases/latest -> Tag, dann SHA256SUMS.txt desselben Releases ->
# Hash des Linux-AppImages. Nur wenn BEIDES sauber da ist, wird der Eintrag
# ersetzt; sonst bleibt die alte Version stehen (Warnung, kein Abbruch).
# Damit kann ein halb hochgeladenes Release den Build nicht kaputt machen.
#
# Aufruf: artcraft-update [REPO]   (Default ~/nixos-config)
# Wird von `fu` und vom naechtlichen update-prewarm aufgerufen.
pkgs.writeShellApplication {
  name = "artcraft-update";
  runtimeInputs = with pkgs; [curl jq coreutils gnugrep];
  text = ''
    repo="''${1:-$HOME/nixos-config}"
    json="$repo/modules/meo/artcraft-versions.json"
    [ -f "$json" ] || { echo "✗ $json fehlt" >&2; exit 1; }

    # Optionales Token gegen das GitHub-Rate-Limit (60 Anfragen/h ohne Token
    # reichen fuer 12 Apps, aber nicht fuer viele Laeufe hintereinander).
    auth=()
    [ -n "''${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

    tmp="$(mktemp)"
    trap 'rm -f "$tmp" "$tmp.new"' EXIT
    cp "$json" "$tmp"
    changed=0

    for app in $(jq -r 'keys[]' "$json"); do
      cur="$(jq -r --arg a "$app" '.[$a].version' "$json")"
      # ADDED 2026-11-13: optionales Feld "owner" pro Eintrag (Default
      # storytold), damit auch Apps anderer Hersteller mitlaufen, z.B.
      # solidcraft von tangency-labs (Paket in modules/meo/artcraft.nix).
      owner="$(jq -r --arg a "$app" '.[$a].owner // "storytold"' "$json")"
      tag="$(curl -fsSL "''${auth[@]}" \
        "https://api.github.com/repos/$owner/$app/releases/latest" \
        | jq -r '.tag_name // empty' || true)"
      if [ -z "$tag" ]; then
        echo "⚠ $app: kein Release gefunden, bleibt auf $cur" >&2
        continue
      fi
      ver="''${tag#v}"
      # Nur stabile Releases: Vorabversionen (0.40.0-rc.4, -nightly...) haben
      # einen Bindestrich in der Version. releases/latest liefert sie zwar
      # nicht, solange Upstream sie als Pre-release markiert; das hier faengt
      # den Fall ab, dass die Markierung einmal fehlt.
      case "$ver" in *-*)
        echo "⚠ $app $ver: Vorabversion, bleibt auf $cur" >&2
        continue ;;
      esac
      [ "$ver" = "$cur" ] && { echo "  $app $cur (aktuell)"; continue; }

      hash="$(curl -fsSL \
        "https://github.com/$owner/$app/releases/download/$tag/SHA256SUMS.txt" \
        | grep -E "[[:space:]]\*?$app-$ver-linux-x86_64\.AppImage$" \
        | grep -oE '^[0-9a-f]{64}' || true)"
      if [ -z "$hash" ]; then
        echo "⚠ $app $ver: kein Hash in SHA256SUMS.txt, bleibt auf $cur" >&2
        continue
      fi

      jq --arg a "$app" --arg v "$ver" --arg h "$hash" \
        '.[$a] += {version: $v, sha256: $h}' "$tmp" >"$tmp.new" && mv "$tmp.new" "$tmp"
      echo "↑ $app $cur → $ver"
      changed=$((changed + 1))
    done

    if [ "$changed" -gt 0 ]; then
      cp "$tmp" "$json"
      echo "→ $changed ArtCraft-App(s) aktualisiert."
    else
      echo "→ ArtCraft: alles aktuell."
    fi
  '';
}
