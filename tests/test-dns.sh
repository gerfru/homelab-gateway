#!/usr/bin/env bash
# test-dns.sh — DNS resolution tests with assertions
# Requires a running CoreDNS instance (make dns-up).
set -euo pipefail

: "${DOMAIN:?DOMAIN not set — run via 'make test-dns' or export DOMAIN}"
: "${TAILSCALE_IP:?TAILSCALE_IP not set — run via 'make test-dns' or export TAILSCALE_IP}"

PASS=0
FAIL=0

assert_dns() {
  local host="$1" expected="$2"
  local result
  result=$(dig +short "@${TAILSCALE_IP}" "$host" 2>/dev/null || true)
  if [[ "$result" == "$expected" ]]; then
    echo "  PASS: $host -> $result"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $host -> got '$result', expected '$expected'"
    FAIL=$((FAIL + 1))
  fi
}

echo "Testing DNS resolution for *.${DOMAIN} via ${TAILSCALE_IP}..."
echo ""
assert_dns "niles.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "garmin.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "vikunja.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "status.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "logs.${DOMAIN}" "${TAILSCALE_IP}"
assert_dns "random-wildcard.${DOMAIN}" "${TAILSCALE_IP}"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
