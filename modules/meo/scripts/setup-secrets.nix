{pkgs, ...}:
pkgs.writeShellScriptBin "setup-secrets" ''
  set -euo pipefail
  JQ="${pkgs.jq}/bin/jq"

  SECRETS_FILE="$HOME/.zshrc-secrets"

  echo "Setting up local secrets from Bitwarden..."
  echo ""

  # Check login status
  STATUS=$(bw status 2>/dev/null | $JQ -r '.status' 2>/dev/null || echo "unauthenticated")

  if [ "$STATUS" = "unauthenticated" ]; then
    echo "Not logged in. Starting Bitwarden login..."
    bw login
    STATUS=$(bw status | $JQ -r '.status')
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
  ERRORS=""

  # --- Notion API Token ---
  NOTION_TOKEN=$(bw get password "Notion API Token" --session "$BW_SESSION" 2>/dev/null || echo "")
  if [ -z "$NOTION_TOKEN" ]; then
    ERRORS="$ERRORS\n  - \"Notion API Token\" (Password = ntn_...)"
  fi

  # --- Kraken API Keys → config.json ---
  KRAKEN_KEY=$(bw get username "Kraken API" --session "$BW_SESSION" 2>/dev/null || echo "")
  KRAKEN_SECRET=$(bw get password "Kraken API" --session "$BW_SESSION" 2>/dev/null || echo "")

  if [ -n "$KRAKEN_KEY" ] && [ -n "$KRAKEN_SECRET" ]; then
    TRADING_DIR="$HOME/quant-trading-bot"
    if [ -d "$TRADING_DIR" ]; then
      cat > "$TRADING_DIR/config.json" << KRAKEN_EOF
{
  "max_open_trades": 2,
  "exchange": {
    "key": "$KRAKEN_KEY",
    "secret": "$KRAKEN_SECRET"
  }
}
KRAKEN_EOF
      chmod 600 "$TRADING_DIR/config.json"
      echo "  Kraken API keys → $TRADING_DIR/config.json"
    fi
  else
    ERRORS="$ERRORS\n  - \"Kraken API\" (Username = API key, Password = API secret)"
  fi

  # --- Write shell secrets file ---
  {
    echo "# Local secrets – managed by setup-secrets, do not commit"
    [ -n "$NOTION_TOKEN" ] && echo "export NOTION_TOKEN=\"$NOTION_TOKEN\""
  } > "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
  echo "  Shell secrets → $SECRETS_FILE"

  # --- Report missing items ---
  if [ -n "$ERRORS" ]; then
    echo ""
    echo "Missing Bitwarden items (create them in the Bitwarden app):"
    echo -e "$ERRORS"
  fi

  echo ""
  echo "Done. Restart your shell or run: source $SECRETS_FILE"
''
