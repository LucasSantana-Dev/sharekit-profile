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
command -v jq >/dev/null 2>&1 || exit 0

# Fork budget: every process spawn costs 50-150 ms under Git Bash on Windows, so
# this path sticks to bash builtins and a handful of external calls.
HOOK_DIR="${BASH_SOURCE[0]%/*}"
RUNTIME="$HOOK_DIR/../.harness/runtime"
[[ -d "$RUNTIME" ]] || mkdir -p "$RUNTIME"

# Slurp the hook payload once with a builtin (no cat fork).
IFS= read -r -d '' input || true
# One jq call yields session id, tool name and the whitespace-normalized command.
{ IFS= read -r sid; IFS= read -r tool_name; IFS= read -r key; } < <(
  jq -r '(.session_id // "" | tostring),
         (.tool_name // "" | tostring),
         (.tool_input.command // .command // "" | tostring | gsub("[[:space:]]+"; " ") | sub("^ "; "") | sub(" $"; ""))' <<<"$input" 2>/dev/null
)
sid="${sid%$'\r'}"; tool_name="${tool_name%$'\r'}"; key="${key%$'\r'}"
[[ "$tool_name" == "Bash" || "$tool_name" == "bash" ]] || exit 0
[[ -n "$key" ]] || exit 0

# State is keyed by session_id so one session (or project) never inherits another's tally.
sid="${sid:-nosession}"; sid="${sid//[^A-Za-z0-9_-]/_}"; sid="${sid:0:64}"
STATE="$RUNTIME/stuck-state-${sid}.jsonl"

# Skip trivial / read-only commands: they repeat legitimately.
case "$key" in
  ls|pwd|clear) exit 0 ;;
esac
if [[ "$key" =~ ^(git[[:space:]]+(status|log|diff|branch|show)|rg[[:space:]]|fd[[:space:]]|cat[[:space:]]|bat[[:space:]]|head[[:space:]]|tail[[:space:]]|wc[[:space:]]) ]]; then
  exit 0
fi
# VCS sync and test runners repeat legitimately (retry after a fix, re-run until green),
# so they get a higher threshold instead of an exemption: a truly stuck push or test
# loop still stops.
limit=3
if [[ "$key" =~ ^(git[[:space:]]+(add|commit|push|pull|fetch)([[:space:]]|$)|npm[[:space:]]+(run[[:space:]]+)?test|pytest|python3?[[:space:]]+-m[[:space:]]+pytest|bats([[:space:]]|$)|go[[:space:]]+test|cargo[[:space:]]+test) ]]; then
  limit=8
fi

# Drop per-session state files untouched for over 7 days. Once per session is enough.
[[ -e "$STATE" ]] || find "$RUNTIME" -name 'stuck-state-*.jsonl' -mtime +7 -delete 2>/dev/null || true

# Tally identical attempts in this session window (last 20 entries).
# sha256sum (Git Bash/Linux) or shasum (macOS); without either every command would
# hash to "" and collide, so fail open instead of blocking unrelated commands.
if command -v sha256sum >/dev/null 2>&1; then
  read -r hash _ < <(printf '%s' "$key" | sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  read -r hash _ < <(printf '%s' "$key" | shasum -a 256)
else
  exit 0
fi
[[ -n "${hash:-}" ]] || exit 0
jq -nc --arg h "$hash" --arg cmd "$key" \
  '{hash: $h, ts: (now | todate), cmd: $cmd}' >> "$STATE"

# Count occurrences of this hash in the trailing window.
count="$(tail -n 20 "$STATE" 2>/dev/null | grep -c "\"hash\":\"$hash\"")"
count="${count:-0}"

if [[ "$count" -ge "$limit" ]]; then
  echo "BLOCKED — Stuck protocol (RULES.md):" >&2
  echo "  attempt:   #${count} of an identical command in this session" >&2
  echo "  command:   $key" >&2
  echo "  action:    surface 'Stuck: [task], attempt ${count}, repeated-identical-command' and switch approach." >&2
  echo "  after 2 approach switches fail, escalate to the human." >&2
  exit 2
fi
exit 0
