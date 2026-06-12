#!/usr/bin/env bash
# Updates TAILSCALE_IP across all services when the Mac's Tailscale IP changes.
# Run this after any IP change (manual or automatic monthly rotation).
# Usage: ./scripts/update-ip.sh [--dry-run]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PULSEBASE_ENV="/Users/gerfru/Documents/PulseBase/env/.env"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# --- Get IPs ---
NEW_IP=$(tailscale ip -4 2>/dev/null) || { echo "ERROR: tailscale not running or not found"; exit 1; }
OLD_IP=$(grep -E '^TAILSCALE_IP=' "$REPO_DIR/.env" | cut -d= -f2)

echo "Current Tailscale IP : $NEW_IP"
echo "Stored IP in .env    : $OLD_IP"

if [[ "$NEW_IP" == "$OLD_IP" ]]; then
    echo ""
    echo "IPs match — checking resolver file..."
    if [[ ! -f /etc/resolver/home.lab ]] || ! grep -q "$NEW_IP" /etc/resolver/home.lab; then
        echo "WARNING: /etc/resolver/home.lab missing or stale — will recreate."
    else
        echo "Everything is up to date."
        exit 0
    fi
fi

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Would update:"
    echo "  $REPO_DIR/.env"
    [[ -f "$PULSEBASE_ENV" ]] && echo "  $PULSEBASE_ENV"
    echo "  /etc/resolver/home.lab"
    echo "  Regenerate DNS + Caddy config"
    echo "  Reload CoreDNS + restart Caddy"
    exit 0
fi

# --- Update .env files ---
echo "Updating $REPO_DIR/.env ..."
sed -i '' "s/^TAILSCALE_IP=.*/TAILSCALE_IP=${NEW_IP}/" "$REPO_DIR/.env"

if [[ -f "$PULSEBASE_ENV" ]]; then
    echo "Updating $PULSEBASE_ENV ..."
    sed -i '' "s/^TAILSCALE_IP=.*/TAILSCALE_IP=${NEW_IP}/" "$PULSEBASE_ENV"
else
    echo "WARNING: $PULSEBASE_ENV not found — skipping."
fi

# --- Regenerate configs ---
echo "Regenerating DNS + Caddy config..."
make -C "$REPO_DIR" generate

# --- Update macOS resolver ---
echo "Updating /etc/resolver/home.lab (requires sudo)..."
sudo mkdir -p /etc/resolver
echo "nameserver ${NEW_IP}" | sudo tee /etc/resolver/home.lab > /dev/null
echo "  /etc/resolver/home.lab → nameserver ${NEW_IP}"

# --- Reload CoreDNS ---
if pgrep -x coredns > /dev/null 2>&1; then
    echo "Reloading CoreDNS..."
    sudo pkill -HUP coredns
    sleep 1
    echo "  CoreDNS reloaded."
else
    echo "WARNING: CoreDNS not running — start with: make dns-up"
fi

# --- Restart Caddy ---
echo "Restarting Caddy..."
docker compose -f "$REPO_DIR/docker-compose.yml" --env-file "$REPO_DIR/.env" up -d --no-deps caddy
echo "  Caddy restarted."

echo ""
echo "================================================================"
echo " IMPORTANT: Update Tailscale Split DNS for other devices!"
echo "----------------------------------------------------------------"
echo " Without this, Windows/iOS/Android cannot resolve *.${DOMAIN}"
echo ""
echo " 1. Open https://login.tailscale.com/admin/dns"
echo " 2. Find the '${DOMAIN}' nameserver entry"
echo " 3. Change IP to: ${NEW_IP}"
echo " 4. Save"
echo "================================================================"
echo ""
echo "Verify with:"
echo "  make test-dns"
echo "  make test-smoke"
