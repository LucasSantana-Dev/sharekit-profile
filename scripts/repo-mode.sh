#!/usr/bin/env bash
# repo-mode.sh — print "solo" or "cooperative" for the repo containing $1 (default: cwd).
#
# Cooperative repos are team/employer/third-party repos where the harness must act as
# a guest: no personal-vault recall injection, no memory writes into personal stores,
# no convention imposition, tightened autonomy. See claude/standards/cooperative-mode.md.
#
# Resolution order:
#   1. Explicit marker: <repo-root>/.agents/mode containing "cooperative" or "solo"
#      (gitignore it in team repos; it is a personal posture flag, not team config).
#   2. Committer diversity: >=2 non-operator, non-bot committers in the last 180 days
#      means other people work here, whatever the remote says. Operator names are read
#      from .harness/operators.json when present (any repo), else SOLO_OWNERS.
#   3. Remote-owner heuristic: owner in SOLO_OWNERS => solo.
#   4. No remote => solo (local experiments are operator-owned by definition).
#   5. Anything else => cooperative (secure default for unknown orgs).
#
# Env:
#   SOLO_OWNERS   space-separated GitHub owners treated as solo (default: empty —
#                 everyone sets their own; empty means unknown orgs go cooperative)
#   OPERATOR_GREP extra grep -i pattern for operator names (merged with operators.json)
set -u

DIR="${1:-$PWD}"
TOP=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || { echo "solo"; exit 0; }

MARKER="$TOP/.agents/mode"
if [ -f "$MARKER" ]; then
  M=$(head -1 "$MARKER" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
  case "$M" in solo|cooperative) echo "$M"; exit 0;; esac
fi

# Operator identities for the committer-diversity check: .harness/operators.json
# (walked up from the repo root) plus OPERATOR_GREP; bots always excluded.
BOT_GREP="bot|dependabot|renovate|github-actions|coderabbit|greptile"
OP_GREP="${OPERATOR_GREP:-}"
OPS_FILE="$TOP/.harness/operators.json"
if [ -f "$OPS_FILE" ] && command -v jq >/dev/null 2>&1; then
  NAMES=$(jq -r '.operators[].name' "$OPS_FILE" 2>/dev/null | tr ' ' '\n' | paste -sd'|' -)
  [ -n "$NAMES" ] && OP_GREP="${OP_GREP:+$OP_GREP|}$NAMES"
fi

OTHERS=$(git -C "$TOP" shortlog -sne --since="180 days ago" 2>/dev/null \
  | grep -viE "${BOT_GREP}${OP_GREP:+|$OP_GREP}" \
  | wc -l | tr -d ' ')
[ "${OTHERS:-0}" -ge 2 ] && { echo "cooperative"; exit 0; }

URL=$(git -C "$TOP" remote get-url origin 2>/dev/null || true)
[ -z "$URL" ] && { echo "solo"; exit 0; }

OWNER=$(printf '%s' "$URL" | sed -E 's#(git@github.com:|https://github.com/)([^/]+)/.*#\2#')
# SOLO_OWNERS default: github handles declared in this repo's operators.json
# (an operator's own repos are solo for them); env overrides entirely.
if [ -z "${SOLO_OWNERS:-}" ] && [ -f "$OPS_FILE" ] && command -v jq >/dev/null 2>&1; then
  SOLO_OWNERS=$(jq -r '.operators[].github // empty' "$OPS_FILE" 2>/dev/null | paste -sd' ' -)
fi
SOLO_OWNERS="${SOLO_OWNERS:-}"
if [ -n "$SOLO_OWNERS" ]; then
  case " $SOLO_OWNERS " in
    *" $OWNER "*) echo "solo"; exit 0 ;;
  esac
fi
echo "cooperative"
exit 0
