#!/usr/bin/env bash
# Sync all GitHub repos to Gitea (branches + tags, no PR refs).
#
# Clones each GitHub repo and pushes to the local Gitea instance.
# Creates missing repos on Gitea automatically. Safe to re-run.
#
# Required environment:
#   GITEA_TOKEN   Gitea API token (Settings → Applications → Access Tokens)
#                 Scopes: repository (read+write), user (read)
#
# Optional environment (override defaults):
#   GITEA_URL     Gitea base URL     (default: https://gitea.${DOMAIN})
#   GITEA_USER    Gitea username     (default: gerfru)
#   GITHUB_USER   GitHub username    (default: gerfru)
#
# Usage:
#   GITEA_TOKEN=xxx ./scripts/github-to-gitea-sync.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if present
if [[ -f "$REPO_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_DIR/.env"
  set +a
fi

: "${GITEA_TOKEN:?GITEA_TOKEN not set — provide a Gitea API token}"
GITEA_URL="${GITEA_URL:-https://gitea.${DOMAIN:-home.lab}}"
GITEA_USER="${GITEA_USER:-gerfru}"
GITHUB_USER="${GITHUB_USER:-gerfru}"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "[$(date +%H:%M:%S)] ✓ $*"; }
warn() { echo "[$(date +%H:%M:%S)] ⚠ $*"; }

gitea_api() {
  local method="$1" path="$2"; shift 2
  curl -sf -X "$method" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    "${GITEA_URL}/api/v1${path}" "$@"
}

# Verify Gitea connection
log "Testing Gitea API connection at ${GITEA_URL}..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  "${GITEA_URL}/api/v1/user")
if [[ "$http_code" != "200" ]]; then
  echo "ERROR: Gitea API returned HTTP ${http_code} — token invalid or Gitea unreachable."
  echo "  Test: curl -s '${GITEA_URL}/api/v1/user' -H 'Authorization: token \$GITEA_TOKEN'"
  exit 1
fi
log "Gitea connection OK."

log "Fetching repo list from GitHub (user: ${GITHUB_USER})..."
repos_raw=$(gh repo list "$GITHUB_USER" --limit 100 \
  --json nameWithOwner,isPrivate \
  --jq '.[] | .nameWithOwner + "|" + (.isPrivate | tostring)')

repo_count=$(echo "$repos_raw" | wc -l | tr -d ' ')
log "Found ${repo_count} repos. Starting sync..."
echo ""

success=0; failed=0

while IFS= read -r entry; do
  repo_full="${entry%|*}"
  is_private="${entry##*|}"
  name="${repo_full##*/}"

  log "── ${name} ──"

  # Gitea doesn't allow dots in repo names — replace with dashes
  gitea_name="${name//./-}"
  [[ "$gitea_name" != "$name" ]] && log "  Renaming for Gitea: ${name} → ${gitea_name}"

  # Create repo on Gitea if it doesn't exist
  if ! gitea_api GET "/repos/${GITEA_USER}/${gitea_name}" -o /dev/null 2>/dev/null; then
    log "  Creating repo on Gitea (private=${is_private})..."
    gitea_api POST "/user/repos" \
      -d "{\"name\": \"${gitea_name}\", \"private\": ${is_private}, \"auto_init\": false}" \
      -o /dev/null || { warn "  Failed to create repo — skipping"; failed=$((failed+1)); continue; }
  fi

  # Clone from GitHub (gh handles auth for private repos automatically)
  clone_dir="$WORKDIR/${name}.git"
  log "  Cloning from GitHub..."
  if ! gh repo clone "${repo_full}" "$clone_dir" -- --mirror --quiet 2>/dev/null; then
    warn "  Clone failed — skipping"
    failed=$((failed+1))
    continue
  fi

  # Push branches + tags (skip refs/pull/* — Gitea blocks those via hook)
  log "  Pushing to Gitea..."
  gitea_remote="https://${GITEA_USER}:${GITEA_TOKEN}@${GITEA_URL#https://}/${GITEA_USER}/${gitea_name}.git"
  git -C "$clone_dir" push --force "$gitea_remote" \
    "+refs/heads/*:refs/heads/*" \
    "+refs/tags/*:refs/tags/*" 2>&1 | grep -v "^$" || true

  ok "${name} synced"
  success=$((success+1))
done <<< "$repos_raw"

echo ""
log "Done. ✓ ${success} synced, ✗ ${failed} failed."
