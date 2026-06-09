#!/usr/bin/env bash
# test-smoke.sh — Stack smoke test (health checks + Prometheus targets)
# Requires a running stack (make up).
set -euo pipefail

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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
