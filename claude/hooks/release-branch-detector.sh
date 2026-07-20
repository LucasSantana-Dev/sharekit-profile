#!/usr/bin/env bash
# UserPromptSubmit hook: detect merge-to-release intent and prompt to use /pr-to-release composite.
#
# Reads: JSON stdin with .prompt (user prompt) and optional .cwd
# Outputs: JSON systemMessage if both conditions met:
#   1. Prompt matches merge-to-release intent patterns
#   2. Local repo has a `release` branch
# Otherwise: silent exit 0
#
# macOS BSD shell-safe: no -P, no GNU-only flags.
set -uo pipefail

INPUT=$(cat 2>/dev/null || true)

# Extract prompt and cwd from JSON stdin
PROMPT=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
  d = json.loads(sys.stdin.read() or "{}")
  print(d.get("prompt") or d.get("user_prompt") or "")
except Exception:
  print("")
' 2>/dev/null)

CWD=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
  d = json.loads(sys.stdin.read() or "{}")
  print(d.get("cwd") or "")
except Exception:
  print("")
' 2>/dev/null)

# Skip if no prompt
[ -z "$PROMPT" ] && exit 0

# Convert prompt to lowercase for case-insensitive matching
P=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Check for merge-to-release intent patterns
# Patterns: "merge to release", "land on release", "ship to release", "release this",
#           "promote to release", "deploy to release", "merge.*into release"
if ! echo "$P" | grep -qE 'merge.{0,15}(to|into|on) release|land.{0,15}(on|to) release|ship.{0,15}to release|release this|promote.{0,15}to release|deploy.{0,15}to release'; then
  exit 0
fi

# Verify repo has a release branch
# If cwd is set, cd there; otherwise use current directory
if [ -n "$CWD" ]; then
  cd "$CWD" 2>/dev/null || exit 0
fi

# Silent probe: check if release branch exists locally or on origin
if ! command -v git &>/dev/null; then
  exit 0
fi

# Try local branch first, then origin
if git rev-parse --verify release >/dev/null 2>&1; then
  # Has release branch locally
  FOUND_RELEASE=1
elif timeout 1 git ls-remote --heads origin release 2>/dev/null | grep -q .; then
  # Has release branch on origin
  FOUND_RELEASE=1
else
  exit 0
fi

# Both conditions met: emit systemMessage hint for pr-to-release composite
jq -n '{"systemMessage": " Composite match: /pr-to-release"}'

exit 0
