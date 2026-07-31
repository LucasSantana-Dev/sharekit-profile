#!/usr/bin/env bash
# repo-mode.sh - print "solo" or "cooperative" for the repo containing $1 (default: cwd).
#
# Cooperative repos are team/employer/third-party repos where the harness must act as
# a guest: no personal-vault recall injection, no memory writes into personal stores,
# no convention imposition, tightened autonomy. See standards/cooperative-mode.md.
#
# Resolution order:
#   1. Explicit marker: <repo-root>/.agents/mode containing "cooperative" or "solo"
#      (gitignore it in team repos; it is a personal posture flag, not team config).
#   2. Remote-owner heuristic: owner in the personal allowlist => solo.
#   3. No remote => solo (local experiments are operator-owned by definition).
#   4. Anything else => cooperative (secure default for unknown orgs).
set -u

DIR="${1:-$PWD}"
TOP=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || { echo "solo"; exit 0; }

MARKER="$TOP/.agents/mode"
if [ -f "$MARKER" ]; then
  M=$(head -1 "$MARKER" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
  case "$M" in solo|cooperative) echo "$M"; exit 0;; esac
fi

# Committer diversity (multi-person-work-ethics 2.4: team behavior is the standing
# default, and it outranks org ownership): >=2 non-operator, non-bot committers in
# the last 180 days means other people work here, whatever the remote says.
OTHERS=$(git -C "$TOP" shortlog -sne --since="180 days ago" 2>/dev/null \
  | grep -viE "lucas|bot|dependabot|renovate|github-actions|coderabbit|greptile" \
  | wc -l | tr -d ' ')
[ "${OTHERS:-0}" -ge 2 ] && { echo "cooperative"; exit 0; }

URL=$(git -C "$TOP" remote get-url origin 2>/dev/null || true)
[ -z "$URL" ] && { echo "solo"; exit 0; }

OWNER=$(printf '%s' "$URL" | sed -E 's#(git@github.com:|https://github.com/)([^/]+)/.*#\2#')
# Personal orgs/accounts that count as solo (space-separated; override via env).
# Quoted-string form keeps public-profile sanitization placeholders valid shell.
SOLO_OWNERS="${SOLO_OWNERS:-<github-user> <project-b>-Projects}"
case " $SOLO_OWNERS " in
  *" $OWNER "*) echo "solo" ;;
  *) echo "cooperative" ;;
esac
exit 0
