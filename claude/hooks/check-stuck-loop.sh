#!/usr/bin/env bash
# check-stuck-loop.sh — PreToolUse hook.
# Enforces the RULES.md "Stuck protocol": if the same task is attempted more
# than 2 times without measurable progress, surface "Stuck: ..." and switch
# approach; after 2 approach switches fail, escalate.
#
# This hook detects the most reliable stuck signal available to a stateless
# per-call hook: repeated identical Bash commands within the current session.
# It maintains a per-session counter in .harness/runtime/stuck-state.json and
# blocks (exit 2) on the 3rd identical attempt, surfacing the Stuck banner.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.harness/runtime/stuck-state.jsonl"
mkdir -p "$(dirname "$STATE")"

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
[[ "$tool_name" == "Bash" || "$tool_name" == "bash" ]] || exit 0

command="$(printf '%s' "$input" | jq -r '.tool_input.command // .command // empty' 2>/dev/null || true)"
[[ -n "$command" ]] || exit 0

# Normalize whitespace for stable matching.
key="$(printf '%s' "$command" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')"
# Skip trivial / read-only commands — they repeat legitimately.
case "$key" in
  ls|pwd|clear|"") exit 0 ;;
esac
if printf '%s' "$key" | grep -Eq '^(git\s+(status|log|diff|branch|show)|rg\s|fd\s|cat\s|bat\s|head\s|tail\s|wc\s)\b'; then
  exit 0
fi

# Tally identical attempts in this session window (last 20 entries).
hash="$(printf '%s' "$key" | shasum -a 256 | awk '{print $1}')"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -nc --arg h "$hash" --arg ts "$ts" --arg cmd "$key" \
  '{hash: $h, ts: $ts, cmd: $cmd}' >> "$STATE"

# Count occurrences of this hash in the trailing window.
count="$(tail -n 20 "$STATE" 2>/dev/null | jq -r --arg h "$hash" 'select(.hash==$h) | .hash' | wc -l | tr -d ' ')"

if [[ "$count" -ge 3 ]]; then
  echo "BLOCKED — Stuck protocol (RULES.md):" >&2
  echo "  attempt:   #${count} of an identical command in this session" >&2
  echo "  command:   $key" >&2
  echo "  action:    surface 'Stuck: [task], attempt ${count}, repeated-identical-command' and switch approach." >&2
  echo "  after 2 approach switches fail, escalate to the human." >&2
  exit 2
fi
exit 0
