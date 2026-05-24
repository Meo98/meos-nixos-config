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

  # --- Obsidian Stack CouchDB → services/.env ---
  OBSIDIAN_USER=$(bw get username "Obsidian_Printbrigata" --session "$BW_SESSION" 2>/dev/null || echo "")
  OBSIDIAN_PW=$(bw get password "Obsidian_Printbrigata" --session "$BW_SESSION" 2>/dev/null || echo "")

  if [ -n "$OBSIDIAN_USER" ] && [ -n "$OBSIDIAN_PW" ]; then
    OBSIDIAN_DIR="$HOME/obsidian-stack"
    if [ -d "$OBSIDIAN_DIR" ]; then
      ENV_FILE="$OBSIDIAN_DIR/services/.env"
      # If .env doesn't exist, seed from .env.example so other vars remain
      if [ ! -f "$ENV_FILE" ] && [ -f "$OBSIDIAN_DIR/services/.env.example" ]; then
        cp "$OBSIDIAN_DIR/services/.env.example" "$ENV_FILE"
      fi
      # Idempotent: remove old COUCHDB_* lines, then append fresh
      if [ -f "$ENV_FILE" ]; then
        ${pkgs.gnused}/bin/sed -i -e '/^COUCHDB_USER=/d' -e '/^COUCHDB_PASSWORD=/d' "$ENV_FILE"
      else
        touch "$ENV_FILE"
      fi
      {
        echo "COUCHDB_USER=$OBSIDIAN_USER"
        echo "COUCHDB_PASSWORD=$OBSIDIAN_PW"
      } >> "$ENV_FILE"
      chmod 600 "$ENV_FILE"
      echo "  Obsidian CouchDB credentials → $ENV_FILE"
    fi
  else
    ERRORS="$ERRORS\n  - \"Obsidian_Printbrigata\" (Username = Admin_Pb, Password = <your strong password>)"
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
