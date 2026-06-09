#!/usr/bin/env bash
# test-pii-regex.sh — Offline PII regex validation
# Validates that promtail-config.yml regex patterns correctly match/reject IPs and emails.
# Runs WITHOUT a live stack. Requires Python 3.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required but not found"
  exit 1
fi

python3 "$SCRIPT_DIR/test-pii-regex.py" "$REPO_DIR/monitoring/promtail-config.yml"
