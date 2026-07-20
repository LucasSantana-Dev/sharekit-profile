#!/usr/bin/env bash
# SessionStart hook: nudge user to /release-cut when release branch is ≥5 commits ahead of main.
# Non-blocking, silent on any error or non-git cwd.
set -u

# Read cwd from JSON stdin
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

# Exit silently if no cwd or not a git repo
[ -z "$CWD" ] && exit 0
[ ! -d "$CWD/.git" ] && exit 0

# Verify both main and release branches exist (silent exit if either missing)
git -C "$CWD" rev-parse --verify main >/dev/null 2>&1 || exit 0
git -C "$CWD" rev-parse --verify release >/dev/null 2>&1 || exit 0

# Count commits: release..main (commits in release that are not in main)
COUNT=$(git -C "$CWD" log main..release --oneline 2>/dev/null | wc -l | tr -d ' ')

# If >= 5 commits ahead, emit nudge
if [ "$COUNT" -ge 5 ]; then
  jq -n --arg count "$COUNT" \
    '{"systemMessage": " release is \($count) commits ahead of main — consider /release-cut to roll up"}'
fi

exit 0
