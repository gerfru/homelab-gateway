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

# Extract subdomains from Caddyfile.tmpl (lines matching: name.${DOMAIN} {)
SUBDOMAINS=$(grep -oE '^[a-z]+\.\$\{DOMAIN\}' "$CADDYFILE" \
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

for sub in $SUBDOMAINS; do
  URL="https://${sub}.${DOMAIN}"
  NAME="${sub}.${DOMAIN}"

  if echo "$EXISTING" | grep -qF "$URL"; then
    echo "  Skip: ${NAME} (exists)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  docker exec "$CONTAINER" sqlite3 "$DB_PATH" \
    "INSERT INTO monitor
      (name, active, user_id, interval, url, type, method,
       maxretries, retry_interval, ignore_tls, maxredirects,
       accepted_statuscodes_json)
     VALUES
      ('${NAME}', 1, 1, 60, '${URL}', 'http', 'GET',
       3, 30, 1, 10, '[\"200-399\"]');"

  echo "  Created: ${NAME}"
  CREATED=$((CREATED + 1))
done

echo ""
echo "Done: ${CREATED} created, ${SKIPPED} skipped."

if [[ $CREATED -gt 0 ]]; then
  echo "Restarting Uptime Kuma to load new monitors..."
  docker compose restart uptime-kuma
  echo "Uptime Kuma restarted."
fi
