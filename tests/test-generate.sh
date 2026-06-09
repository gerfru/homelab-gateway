#!/usr/bin/env bash
# test-generate.sh — Golden-file test for template generation
# Runs WITHOUT a live stack. Uses fixed test values.
set -euo pipefail

export DOMAIN=test.example
export TAILSCALE_IP=100.64.0.1
export ZONE_FILE=/repo/dns/home.lab.zone

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/golden"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

check() {
  local label="$1" generated="$2" golden="$3"
  if diff -u "$golden" "$generated" >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    diff -u "$golden" "$generated" || true
    FAIL=$((FAIL + 1))
  fi
}

echo "Generating from templates..."
# shellcheck disable=SC2016
{ echo "# GENERATED FILE — DO NOT EDIT (source: dns/Corefile.macos.tmpl)"; \
  envsubst '$DOMAIN $TAILSCALE_IP $ZONE_FILE' < "$REPO_DIR/dns/Corefile.macos.tmpl"; } > "$TMP_DIR/Corefile.macos"
# shellcheck disable=SC2016
{ echo "# GENERATED FILE — DO NOT EDIT (source: dns/Corefile.tmpl)"; \
  envsubst '$DOMAIN $TAILSCALE_IP' < "$REPO_DIR/dns/Corefile.tmpl"; } > "$TMP_DIR/Corefile.linux"
# shellcheck disable=SC2016
{ echo "; GENERATED FILE — DO NOT EDIT (source: dns/home.lab.zone.tmpl)"; \
  envsubst '$DOMAIN $TAILSCALE_IP' < "$REPO_DIR/dns/home.lab.zone.tmpl"; } > "$TMP_DIR/home.lab.zone"
# shellcheck disable=SC2016
{ echo "# GENERATED FILE — DO NOT EDIT (source: Caddyfile.tmpl)"; \
  envsubst '$DOMAIN' < "$REPO_DIR/Caddyfile.tmpl"; } > "$TMP_DIR/Caddyfile"

# Check for unreplaced ${...} variables
echo "Checking for unreplaced variables..."
for f in "$TMP_DIR"/*; do
  if grep -qE '\$\{[A-Z_]+\}' "$f"; then
    echo "  FAIL: Unreplaced variables in $(basename "$f")"
    grep -nE '\$\{[A-Z_]+\}' "$f"
    FAIL=$((FAIL + 1))
  fi
done

# Golden-file comparison
echo "Comparing against golden files..."
check "Caddyfile" "$TMP_DIR/Caddyfile" "$GOLDEN_DIR/Caddyfile"
check "Corefile (Linux)" "$TMP_DIR/Corefile.linux" "$GOLDEN_DIR/Corefile.linux"
check "Corefile (macOS)" "$TMP_DIR/Corefile.macos" "$GOLDEN_DIR/Corefile.macos"
check "home.lab.zone" "$TMP_DIR/home.lab.zone" "$GOLDEN_DIR/home.lab.zone"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
