#!/usr/bin/env bash
# test-smoke.sh — Stack smoke test (health checks + Prometheus targets + security headers)
# Requires a running stack (make up).
set -euo pipefail

: "${DOMAIN:?DOMAIN not set — run via 'make test-smoke' or export DOMAIN}"
: "${TAILSCALE_IP:?TAILSCALE_IP not set — run via 'make test-smoke' or export TAILSCALE_IP}"

PASS=0
FAIL=0

assert_healthy() {
  local svc="$1"
  local health
  health=$(docker compose ps --format json "$svc" 2>/dev/null \
    | jq -r '.Health // .State' 2>/dev/null || echo "missing")
  if [[ "$health" == "healthy" ]]; then
    echo "  PASS: $svc is healthy"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $svc — status: $health"
    FAIL=$((FAIL + 1))
  fi
}

assert_prom_target() {
  local job="$1"
  local up
  up=$(docker compose exec -T prometheus wget -qO- \
    "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22${job}%22%7D" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // "missing"' 2>/dev/null || echo "error")
  if [[ "$up" == "1" ]]; then
    echo "  PASS: Prometheus target '$job' is up"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Prometheus target '$job' — up=$up"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Health Checks ==="
assert_healthy caddy
assert_healthy grafana
assert_healthy prometheus
assert_healthy node-exporter
assert_healthy uptime-kuma
assert_healthy socket-proxy

echo ""
echo "=== Prometheus Targets ==="
assert_prom_target node
assert_prom_target caddy
assert_prom_target loki
assert_prom_target grafana
assert_prom_target promtail
assert_prom_target tempo

assert_header() {
  local subdomain="$1" header="$2" expected="$3"
  local value
  value=$(curl -sk -o /dev/null -D - \
    -H "Host: ${subdomain}.${DOMAIN}" \
    "https://${TAILSCALE_IP}/" \
    | grep -i "^${header}:" | head -1 \
    | sed 's/^[^:]*: *//' | tr -d '\r' || true)
  if [[ -n "$value" && "$value" == *"$expected"* ]]; then
    echo "  PASS: ${subdomain} — ${header}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${subdomain} — ${header}: got '${value}', expected '${expected}'"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Security Headers ==="
# Strict CSP subdomain
assert_header "niles" "Strict-Transport-Security" "max-age=31536000"
assert_header "niles" "X-Frame-Options" "DENY"
assert_header "niles" "X-Content-Type-Options" "nosniff"
assert_header "niles" "Content-Security-Policy" "default-src 'self'"
# Relaxed CSP subdomain
assert_header "status" "Strict-Transport-Security" "max-age=31536000"
assert_header "status" "Content-Security-Policy" "unsafe-inline"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
