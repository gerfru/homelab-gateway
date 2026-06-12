#!/usr/bin/env bash
# github-to-gitea-sync.sh — Sync all GitHub repos to the local Gitea instance.
#
# Pulls every repo from GitHub and pushes branches + tags to Gitea.
# Missing repos are created automatically with matching visibility.
# Safe to re-run — existing repos are updated, not recreated.
#
# This is the REVERSE direction of gitea-mirror.sh:
#   GitHub → Gitea  (this script, manual / scheduled)
#   Gitea  → GitHub (gitea-mirror.sh, automatic push-mirror on commit)
#
# Typical use cases:
#   - Initial import of all GitHub repos into a fresh Gitea instance
#   - Pulling back GitHub-side changes (release-please commits, merged PRs)
#   - Recovering Gitea from a backup by re-syncing from GitHub
#   - Automated sync after CI succeeds or on a daily schedule
#
# Prerequisites:
#   - gh CLI installed and authenticated (gh auth login)
#   - Gitea reachable at GITEA_URL (via Tailscale or local network)
#   - GITEA_TOKEN with scopes: repository (read+write), user (read)
#     Create at: https://<your-gitea> → Settings → Applications → Access Tokens
#
# Required environment:
#   GITEA_TOKEN   Gitea API token
#   GITEA_USER    Gitea username
#   GITHUB_USER   GitHub username
#
# Optional environment (defaults read from .env):
#   GITEA_URL     Gitea base URL   (default: https://gitea.${DOMAIN})
#
# Usage:
#   ./scripts/github-to-gitea-sync.sh                # sync all repos (manual)
#   ./scripts/github-to-gitea-sync.sh --dry-run      # preview only, no changes
#   ./scripts/github-to-gitea-sync.sh --if-ci-passed # sync only if CI passed on main since last sync
#   ./scripts/github-to-gitea-sync.sh --if-new       # sync only if any repo has new pushes
#
# Scheduling (add to crontab with: crontab -e):
#   # Sync within ~30min of a successful CI run on homelab-gateway main:
#   */30 * * * * cd /path/to/homelab-gateway && ./scripts/github-to-gitea-sync.sh --if-ci-passed >> /tmp/gitea-sync.log 2>&1
#   # Daily hard sync at 03:00 — catches repos without CI and ensures max 24h lag:
#   0 3 * * * cd /path/to/homelab-gateway && ./scripts/github-to-gitea-sync.sh --if-new >> /tmp/gitea-sync.log 2>&1
#
# Notes:
#   - refs/pull/* (GitHub PR refs) are intentionally skipped — Gitea blocks them
#   - *.github.io repos are skipped — GitHub Pages is GitHub-specific
#   - Repo names with dots are renamed (dots → dashes) for Gitea compatibility
#   - --force push is used to handle rewritten git history
#   - Last sync timestamp is stored at ~/.cache/github-to-gitea-last-sync

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
: "${GITEA_USER:?GITEA_USER not set — your Gitea username}"
: "${GITHUB_USER:?GITHUB_USER not set — your GitHub username}"

DRY_RUN=false
CI_GATED=false
NEW_GATED=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)       DRY_RUN=true ;;
    --if-ci-passed)  CI_GATED=true ;;
    --if-new)        NEW_GATED=true ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

LAST_SYNC_FILE="${HOME}/.cache/github-to-gitea-last-sync"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

log()  { [[ "$DRY_RUN" == "true" ]] && echo "[dry-run] $*" || echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "[$(date +%H:%M:%S)] ✓ $*"; }
warn() { echo "[$(date +%H:%M:%S)] ⚠ $*"; }

gitea_api() {
  local method="$1" path="$2"; shift 2
  curl -sf -X "$method" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    "${GITEA_URL}/api/v1${path}" "$@"
}

# Returns 0 if a new successful CI run on homelab-gateway main has appeared since last sync.
check_ci_passed() {
  local last_sync repo latest_success
  last_sync=$(cat "$LAST_SYNC_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
  repo="${GITHUB_USER}/homelab-gateway"

  log "CI-gate: checking ${repo} main (last sync: ${last_sync})..."

  latest_success=$(gh run list \
    --repo "$repo" \
    --branch main \
    --status success \
    --limit 1 \
    --json updatedAt \
    --jq '.[0].updatedAt // ""' 2>/dev/null || echo "")

  if [[ -z "$latest_success" ]]; then
    log "No successful CI runs found on ${repo} main — skipping."
    return 1
  fi

  if [[ "$latest_success" > "$last_sync" ]]; then
    log "New CI success at ${latest_success} — proceeding with sync."
    return 0
  else
    log "No new CI success since last sync — skipping."
    return 1
  fi
}

# Returns 0 if any GitHub repo has been pushed to since last sync.
check_if_new() {
  local last_sync newest_push
  last_sync=$(cat "$LAST_SYNC_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")

  log "Checking for new GitHub activity since ${last_sync}..."

  newest_push=$(gh repo list "$GITHUB_USER" --limit 100 \
    --json pushedAt \
    --jq 'max_by(.pushedAt) | .pushedAt // ""' 2>/dev/null || echo "")

  if [[ -z "$newest_push" ]]; then
    log "Could not determine latest push time — skipping."
    return 1
  fi

  if [[ "$newest_push" > "$last_sync" ]]; then
    log "New activity detected (latest push: ${newest_push}) — proceeding with sync."
    return 0
  else
    log "Nothing new since last sync — skipping."
    return 1
  fi
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

# Smart-sync gate: exit early if nothing warrants a sync
if [[ "$CI_GATED" == "true" ]]; then
  check_ci_passed || exit 0
elif [[ "$NEW_GATED" == "true" ]]; then
  check_if_new || exit 0
fi

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

  # Skip GitHub Pages repos (*.github.io) — they're GitHub-specific
  if [[ "$name" == *.github.io ]]; then
    log "  Skipping GitHub Pages repo — not applicable on Gitea"
    continue
  fi

  # Gitea doesn't allow dots in repo names — replace with dashes
  gitea_name="${name//./-}"
  [[ "$gitea_name" != "$name" ]] && log "  Renaming for Gitea: ${name} → ${gitea_name}"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "  Would sync → ${GITEA_URL}/${GITEA_USER}/${gitea_name} (private=${is_private})"
    success=$((success+1))
    continue
  fi

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

# Record successful sync timestamp (used by --if-ci-passed and --if-new)
if [[ "$DRY_RUN" != "true" ]]; then
  mkdir -p "$(dirname "$LAST_SYNC_FILE")"
  date -u "+%Y-%m-%dT%H:%M:%SZ" > "$LAST_SYNC_FILE"
  log "Last sync recorded: $(cat "$LAST_SYNC_FILE")"
fi
