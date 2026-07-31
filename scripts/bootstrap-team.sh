#!/usr/bin/env bash
# bootstrap-team.sh — one-command team onboarding scaffold for sharekit-profile.
#
# Idempotent: state-check before mutation; existing files are never overwritten.
# Creates, in the CURRENT repo (or --target DIR):
#   .harness/operators.json   stub seeded from your git identity (if absent)
#   .claude/settings.json     committed team-settings stub (if absent)
#   .agents/mode              posture marker: cooperative (team default)
# Prints the starter profile: which hooks + skills to enable first (week 1).
#
# Usage: bash scripts/bootstrap-team.sh [--target DIR] [--dry-run]

set -euo pipefail

TARGET="$PWD"
DRY_RUN=0
WITH_REVIEW=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --with-review) WITH_REVIEW=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

say() { echo "bootstrap: $*"; }
write() { # write <path> <content>
  local path="$1" content="$2"
  if [ -f "$path" ]; then
    say "already done - skipping $path (exists)"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN would create $path"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  say "created $path"
}

NAME="$(git -C "$TARGET" config user.name 2>/dev/null || echo "Your Name")"
EMAIL="$(git -C "$TARGET" config user.email 2>/dev/null || echo "you@example.com")"
GH="$(git -C "$TARGET" remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)([^/]+)/.*#\2#' || true)"

write "$TARGET/.harness/operators.json" "{
  \"schema\": \"harness-operators/v1\",
  \"operators\": [
    {
      \"name\": \"$NAME\",
      \"github\": \"${GH:-your-github-user}\",
      \"emails\": [\"$EMAIL\"],
      \"role\": \"owner\"
    }
  ]
}"

write "$TARGET/.claude/settings.json" "{
  \"//\": \"Committed team settings (project tier). Personal overrides go in .claude/settings.local.json (gitignored). See sharekit-profile docs/configuration.md for the precedence contract.\",
  \"permissions\": {
    \"allow\": [],
    \"deny\": []
  }
}"

write "$TARGET/.agents/mode" "cooperative"

cat <<EOF
bootstrap: starter profile (week 1 — enable these first, expand later):
  hooks:  hooks/check-identity.sh, hooks/check-dangerous-patterns.sh, hooks/policy-gate.sh
  skills: plan, verify, tdd
  why:    rollout evidence says teams stall when week-1 ships 40+ hooks; start
          with 1-3, add per pain. See docs/team-rollout-playbook.md (Phase 4).
bootstrap: posture check: bash $PROFILE_ROOT/scripts/repo-mode.sh "$TARGET"
EOF

if [ "$WITH_REVIEW" -eq 1 ]; then
  TEMPLATE="$PROFILE_ROOT/.github/workflows-templates/ai-review.yml"
  if [ -f "$TEMPLATE" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      say "DRY-RUN would install $TARGET/.github/workflows/ai-review.yml"
    else
      mkdir -p "$TARGET/.github/workflows"
      if [ -f "$TARGET/.github/workflows/ai-review.yml" ]; then
        say "already done - skipping ai-review.yml (exists)"
      else
        cp "$TEMPLATE" "$TARGET/.github/workflows/ai-review.yml"
        say "installed ai-review.yml - set ANTHROPIC_API_KEY in repo secrets"
      fi
    fi
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  say "DRY-RUN complete - no files written"
else
  say "done. Next: docs/team-onboarding.md week-1 checklist."
fi
