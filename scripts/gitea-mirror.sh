#!/usr/bin/env bash
# gitea-mirror.sh — Configure push mirrors from Gitea to GitHub for all repos.
#
# Uses Gitea's built-in push mirror feature via API. For each repo found in
# Gitea, creates a GitHub push mirror if one doesn't already exist. Gitea then
# handles the actual push on its own schedule (default: every 24h).
#
# Required environment:
#   GITEA_URL            Gitea base URL        (default: https://gitea.${DOMAIN})
#   GITEA_TOKEN          Gitea API token        (from secrets/renovate_token or dedicated token)
#   GITHUB_MIRROR_TOKEN  GitHub PAT             (from .env)
#   GITHUB_MIRROR_OWNER  GitHub username/org    (from .env)
#
# Usage:
#   ./scripts/gitea-mirror.sh              # one-shot: configure mirrors for all repos
#   0 3 * * * cd /path/to/repo && ./scripts/gitea-mirror.sh  # cron: daily at 03:00

set -euo pipefail

# --- Configuration ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if present
if [[ -f "$REPO_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_DIR/.env"
  set +a
fi

: "${GITEA_URL:=https://gitea.${DOMAIN}}"
: "${GITEA_TOKEN:?GITEA_TOKEN not set — provide a Gitea API token}"
: "${GITHUB_MIRROR_TOKEN:?GITHUB_MIRROR_TOKEN not set — provide a GitHub PAT}"
: "${GITHUB_MIRROR_OWNER:?GITHUB_MIRROR_OWNER not set — provide your GitHub username}"

MIRROR_INTERVAL="${MIRROR_INTERVAL:-24h0m0s}"

# --- Helpers ---

gitea_api() {
  local method="$1" path="$2"
  shift 2
  curl -sf -X "$method" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    "${GITEA_URL}/api/v1${path}" "$@"
}

log() { echo "[$(date +%H:%M:%S)] $*"; }

# --- Main ---

log "Discovering Gitea repos..."

# Paginate through all repos the token can see
page=1
repos=()
while true; do
  response=$(gitea_api GET "/repos/search?limit=50&page=${page}")
  batch=$(echo "$response" | jq -r '.data[]?.full_name // empty' 2>/dev/null)
  [[ -z "$batch" ]] && break
  while IFS= read -r name; do
    repos+=("$name")
  done <<< "$batch"
  page=$((page + 1))
done

if [[ ${#repos[@]} -eq 0 ]]; then
  log "No repos found. Check GITEA_TOKEN permissions."
  exit 0
fi

log "Found ${#repos[@]} repo(s)."

created=0
skipped=0

for repo in "${repos[@]}"; do
  owner="${repo%%/*}"
  name="${repo##*/}"

  # Check existing push mirrors
  mirrors=$(gitea_api GET "/repos/${owner}/${name}/push_mirrors" 2>/dev/null || echo "[]")
  github_url="https://github.com/${GITHUB_MIRROR_OWNER}/${name}.git"

  if echo "$mirrors" | jq -e ".[] | select(.remote_address == \"${github_url}\")" >/dev/null 2>&1; then
    log "  ${repo} — mirror exists, skipping"
    skipped=$((skipped + 1))
    continue
  fi

  # Create push mirror
  log "  ${repo} — creating mirror → ${github_url}"
  result=$(gitea_api POST "/repos/${owner}/${name}/push_mirrors" \
    -d "{
      \"remote_address\": \"${github_url}\",
      \"remote_username\": \"${GITHUB_MIRROR_OWNER}\",
      \"remote_password\": \"${GITHUB_MIRROR_TOKEN}\",
      \"interval\": \"${MIRROR_INTERVAL}\",
      \"sync_on_commit\": false
    }" 2>&1) || {
    log "  ERROR: Failed to create mirror for ${repo}: ${result}"
    continue
  }

  created=$((created + 1))
done

log "Done. Created: ${created}, Skipped (existing): ${skipped}, Total: ${#repos[@]}"
