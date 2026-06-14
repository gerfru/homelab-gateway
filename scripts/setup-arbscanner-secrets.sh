#!/usr/bin/env bash
# Setup Docker Secrets for arbscanner (idempotent — safe to re-run)
set -euo pipefail

SECRETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/secrets"
mkdir -p "$SECRETS_DIR"

echo "=== arbscanner secret setup ==="
echo ""

# --- kalshi_api_key_id ---
if [ -f "$SECRETS_DIR/kalshi_api_key_id" ] && [ -s "$SECRETS_DIR/kalshi_api_key_id" ]; then
  echo "✓ kalshi_api_key_id already exists (skipping)"
else
  printf "Enter your Kalshi API Key ID: "
  read -r key_id
  if [ -z "$key_id" ]; then
    echo "ERROR: API Key ID cannot be empty." >&2
    exit 1
  fi
  printf '%s' "$key_id" > "$SECRETS_DIR/kalshi_api_key_id"
  chmod 600 "$SECRETS_DIR/kalshi_api_key_id"
  echo "✓ kalshi_api_key_id written"
fi

# --- kalshi_private_key ---
if [ -f "$SECRETS_DIR/kalshi_private_key" ] && grep -q "BEGIN" "$SECRETS_DIR/kalshi_private_key" 2>/dev/null; then
  echo "✓ kalshi_private_key already exists (skipping)"
else
  printf "Path to your Kalshi RSA private key (.pem): "
  read -r pem_path
  pem_path="${pem_path/#\~/$HOME}"
  if [ ! -f "$pem_path" ]; then
    echo "ERROR: File not found: $pem_path" >&2
    exit 1
  fi
  if ! grep -q "BEGIN" "$pem_path"; then
    echo "ERROR: File does not look like a PEM key (no BEGIN header found)." >&2
    exit 1
  fi
  cp "$pem_path" "$SECRETS_DIR/kalshi_private_key"
  chmod 600 "$SECRETS_DIR/kalshi_private_key"
  echo "✓ kalshi_private_key copied"
fi

echo ""
echo "Secrets ready. Build and start arbscanner with:"
echo "  make build-arbscanner"
echo "  docker compose up -d arbscanner"
