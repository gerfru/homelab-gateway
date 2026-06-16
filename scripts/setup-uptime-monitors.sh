#!/usr/bin/env bash
# setup-uptime-monitors.sh — Provision Uptime Kuma monitors from Caddyfile.tmpl
#
# Reads subdomains from Caddyfile.tmpl and creates HTTPS monitors
# in Uptime Kuma's SQLite database. Restarts Uptime Kuma to apply.
# Idempotent — skips monitors that already exist.
#
# Usage: ./scripts/setup-uptime-monitors.sh

set -euo pipefail

CADDYFILE="Caddyfile.tmpl"
CONTAINER="gateway-uptime"
DB_PATH="/app/data/kuma.db"

# Source DOMAIN from .env if available
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi
DOMAIN="${DOMAIN:?Set DOMAIN in .env or environment}"

# Validate DOMAIN format: only lowercase alphanumeric, dots, hyphens
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
  echo "ERROR: Invalid DOMAIN format: '$DOMAIN'" >&2
  echo "  DOMAIN must contain only lowercase letters, digits, dots, and hyphens." >&2
  exit 1
fi

# Extract subdomains from Caddyfile.tmpl (lines matching: name.${DOMAIN} {)
# shellcheck disable=SC2016
SUBDOMAINS=$(grep -oE '^[a-z][-a-z0-9]*\.\$\{DOMAIN\}' "$CADDYFILE" \
  | sed 's/\.\${DOMAIN}//' | sort -u)

if [[ -z "$SUBDOMAINS" ]]; then
  echo "No subdomains found in $CADDYFILE"
  exit 1
fi

echo "Subdomains found in $CADDYFILE:"
for sub in $SUBDOMAINS; do
  echo "  https://${sub}.${DOMAIN}"
done
echo ""

# Get existing monitor URLs
EXISTING=$(docker exec "$CONTAINER" sqlite3 "$DB_PATH" \
  "SELECT url FROM monitor;" 2>/dev/null || true)

CREATED=0
SKIPPED=0

# Escape single quotes for sqlite3 (double them per SQL standard)
safe_sql() { printf '%s' "${1//\'/\'\'}"; }

for sub in $SUBDOMAINS; do
  URL="https://${sub}.${DOMAIN}"
  NAME="${sub}.${DOMAIN}"

  if echo "$EXISTING" | grep -qF "$URL"; then
    echo "  Skip: ${NAME} (exists)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  SAFE_NAME=$(safe_sql "$NAME")
  SAFE_URL=$(safe_sql "$URL")

  docker exec "$CONTAINER" sqlite3 "$DB_PATH" \
    "INSERT INTO monitor
      (name, active, user_id, interval, url, type, method,
       maxretries, retry_interval, ignore_tls, maxredirects,
       accepted_statuscodes_json)
     VALUES
      ('${SAFE_NAME}', 1, 1, 60, '${SAFE_URL}', 'http', 'GET',
       3, 30, 1, 10, '[\"200-399\"]');"

  echo "  Created: ${NAME}"
  CREATED=$((CREATED + 1))
done

echo ""
echo "Done: ${CREATED} created, ${SKIPPED} skipped."

# --- Enhanced monitors (keyword checks, specific endpoints) ---
echo ""
echo "=== Enhanced Monitors ==="

add_keyword_monitor() {
  local name="$1" url="$2" keyword="$3"
  if echo "$EXISTING" | grep -qF "$url"; then
    echo "  Skip: ${name} (exists)"
    return
  fi
  local safe_name safe_url safe_kw
  safe_name=$(safe_sql "$name")
  safe_url=$(safe_sql "$url")
  safe_kw=$(safe_sql "$keyword")
  docker exec "$CONTAINER" sqlite3 "$DB_PATH" \
    "INSERT INTO monitor
      (name, active, user_id, interval, url, type, method,
       maxretries, retry_interval, ignore_tls, maxredirects,
       accepted_statuscodes_json, keyword)
     VALUES
      ('${safe_name}', 1, 1, 60, '${safe_url}', 'keyword', 'GET',
       3, 30, 1, 10, '[\"200-299\"]', '${safe_kw}');"
  echo "  Created: ${name}"
  CREATED=$((CREATED + 1))
}

add_keyword_monitor \
  "gitea.${DOMAIN} — Health API" \
  "https://gitea.${DOMAIN}/api/healthz" \
  "\"pass\""

add_keyword_monitor \
  "arb.${DOMAIN} — Health API" \
  "https://arb.${DOMAIN}/health" \
  '"ok"'

add_keyword_monitor \
  "niles.${DOMAIN} — Liveness" \
  "https://niles.${DOMAIN}/health" \
  '"ok"'

# /ready returns 200 {"status":"ready"} when DB+migrations are healthy, else 503.
# The 503 is rejected by the 200-299 status filter, so readiness fails correctly.
add_keyword_monitor \
  "niles.${DOMAIN} — Readiness" \
  "https://niles.${DOMAIN}/ready" \
  '"ready"'

if [[ $CREATED -gt 0 ]]; then
  echo ""
  echo "Restarting Uptime Kuma to load new monitors..."
  docker compose restart uptime-kuma
  echo "Uptime Kuma restarted."
fi
