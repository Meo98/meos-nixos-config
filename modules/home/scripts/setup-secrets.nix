{pkgs, ...}:
pkgs.writeShellScriptBin "setup-secrets" ''
  set -euo pipefail

  SECRETS_FILE="$HOME/.zshrc-secrets"
  BW_ITEM_NAME="Notion API Token"

  echo "Setting up local secrets from Bitwarden..."
  echo ""

  # Check login status
  STATUS=$(bw status 2>/dev/null | ${pkgs.jq}/bin/jq -r '.status' 2>/dev/null || echo "unauthenticated")

  if [ "$STATUS" = "unauthenticated" ]; then
    echo "Not logged in. Starting Bitwarden login..."
    bw login
    STATUS=$(bw status | ${pkgs.jq}/bin/jq -r '.status')
  fi

  # Unlock vault if locked
  if [ "$STATUS" = "locked" ]; then
    echo "Vault is locked. Enter your master password to unlock:"
    export BW_SESSION
    BW_SESSION=$(bw unlock --raw)
  fi

  if [ -z "''${BW_SESSION:-}" ]; then
    echo "Could not unlock vault. Run 'bw login' and try again."
    exit 1
  fi

  echo "Fetching secrets from Bitwarden..."

  # Fetch Notion token
  NOTION_TOKEN=$(bw get password "$BW_ITEM_NAME" --session "$BW_SESSION" 2>/dev/null || echo "")

  if [ -z "$NOTION_TOKEN" ]; then
    echo ""
    echo "Item \"$BW_ITEM_NAME\" not found in Bitwarden."
    echo "Create it first:"
    echo "  bw create item (interactive) – or add it via the Bitwarden app"
    echo "  Name: $BW_ITEM_NAME"
    echo "  Password: your Notion API token (ntn_...)"
    exit 1
  fi

  # Write secrets file
  cat > "$SECRETS_FILE" << EOF
# Local secrets – managed by setup-secrets, do not commit
export NOTION_TOKEN="$NOTION_TOKEN"
EOF
  chmod 600 "$SECRETS_FILE"

  echo ""
  echo "Done. Secrets written to $SECRETS_FILE"
  echo "Restart your shell or run: source $SECRETS_FILE"
''
