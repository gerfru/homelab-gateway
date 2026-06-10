#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# test-dns.sh — DNS resolution tests with assertions
# Requires a running CoreDNS instance (make dns-up).
set -euo pipefail

: "${DOMAIN:?DOMAIN not set — run via 'make test-dns' or export DOMAIN}"
: "${TAILSCALE_IP:?TAILSCALE_IP not set — run via 'make test-dns' or export TAILSCALE_IP}"

# Prerequisite: CoreDNS must be reachable
echo "Checking CoreDNS reachability at ${TAILSCALE_IP}:53..."
if ! dig +short +timeout=3 +retry=1 "@${TAILSCALE_IP}" "${DOMAIN}" >/dev/null 2>&1; then
  echo "ERROR: CoreDNS not reachable at ${TAILSCALE_IP}:53"
  echo "  Start it with: make dns-up"
  exit 1
fi
echo "CoreDNS reachable."
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

assert_dns() {
  local host="$1" expected="$2"
  local result
  result=$(dig +short "@${TAILSCALE_IP}" "$host" 2>/dev/null || true)
  if [[ "$result" == "$expected" ]]; then
    pass "$host -> $result"
  else
    fail "$host -> got '$result', expected '$expected'"
  fi
}

echo "Testing DNS resolution for *.${DOMAIN} via ${TAILSCALE_IP}..."
echo ""
assert_dns "gitea.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "niles.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "garmin.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "vikunja.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "whatsapp.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "status.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "logs.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "prometheus.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "metrics.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "random-wildcard.${DOMAIN}" "${TAILSCALE_IP}"

results
