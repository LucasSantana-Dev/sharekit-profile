#!/usr/bin/env bash
# review-state.sh — fetch prior review state for incremental re-review (spec D5).
#
# Store of record: the bot's own prior review + inline threads on the PR,
# plus the hidden fingerprint block (HTML-comment JSON) inside the bot's
# summary comment. Emits the pieces the coordinator prompt needs:
#   <previous_review>   text of the last coordinator summary
#   <fingerprints>      JSON array of prior finding fingerprints (+ status)
#
# Usage: review-state.sh <pr-number> [--repo owner/repo]
# Env: REVIEW_BOT_LOGIN (default: github-actions[bot]).
# Degrades gracefully: first run, no prior state, or read-only token
# (fork PRs) -> empty state on stdout, exit 0 (full review proceeds).

set -euo pipefail

[ $# -ge 1 ] || { echo "usage: review-state.sh <pr-number> [--repo owner/repo]" >&2; exit 2; }
PR="$1"; shift
REPO_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in --repo) REPO_ARG="$2"; shift 2 ;; *) shift ;;
  esac
done
BOT="${REVIEW_BOT_LOGIN:-github-actions[bot]}"

# Read-only token (fork PRs) or gh failure -> empty state, never block.
reviews="$(gh api "repos/${REPO_ARG:-{owner}/{repo}}/pulls/$PR/reviews" 2>/dev/null || true)"
[ -z "$reviews" ] && { echo '{"previous_review": "", "fingerprints": []}'; exit 0; }

last_summary="$(printf '%s' "$reviews" | jq -r --arg bot "$BOT" \
  '[.[] | select(.user.login == $bot and .body != "")] | last | .body // ""')"

# Hidden fingerprint block: <!-- review-state: {...} --> in the summary.
fp_block="$(printf '%s' "$last_summary" | grep -o '<!-- review-state: {.*} -->' | tail -1 || true)"
fps="[]"
if [ -n "$fp_block" ]; then
  fps="$(printf '%s' "$fp_block" | sed 's/<!-- review-state: //; s/ -->//' | jq -c '.findings // []' 2>/dev/null || echo '[]')"
fi

# Strip the state block out of the human-readable summary.
clean_summary="$(printf '%s' "$last_summary" | sed 's/<!-- review-state: {.*} -->//')"

jq -n --arg prev "$clean_summary" --argjson fps "$fps" \
  '{previous_review: $prev, fingerprints: $fps}'
exit 0
