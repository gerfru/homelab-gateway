#!/usr/bin/env bash
# github-to-gitea-sync.sh — Sync all GitHub repos to the local Gitea instance.
#
# Pulls every repo from GitHub and pushes branches + tags to Gitea.
# Missing repos are created automatically with matching visibility.
# Safe to re-run — existing repos are updated, not recreated.
#
# This is the REVERSE direction of gitea-mirror.sh:
#   GitHub → Gitea  (this script, manual / one-shot)
#   Gitea  → GitHub (gitea-mirror.sh, automatic push-mirror on commit)
#
# Typical use cases:
#   - Initial import of all GitHub repos into a fresh Gitea instance
#   - Pulling back GitHub-side changes (release-please commits, merged PRs)
#   - Recovering Gitea from a backup by re-syncing from GitHub
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
#   GITEA_TOKEN=xxx ./scripts/github-to-gitea-sync.sh            # sync all
#   GITEA_TOKEN=xxx ./scripts/github-to-gitea-sync.sh --dry-run  # preview only
#
# Notes:
#   - refs/pull/* (GitHub PR refs) are intentionally skipped — Gitea blocks them
#   - *.github.io repos are skipped — GitHub Pages is GitHub-specific
#   - Repo names with dots are renamed (dots → dashes) for Gitea compatibility
#   - --force push is used to handle rewritten git history

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

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
[[ "$DRY_RUN" == "true" ]] && log() { echo "[dry-run] $*"; }

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
