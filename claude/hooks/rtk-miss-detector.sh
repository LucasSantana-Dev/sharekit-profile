#!/usr/bin/env bash
# Logs Bash commands that produced large output BUT were not rtk-wrapped.
# Review weekly to find registry expansion candidates.
#
# Output: ~/.claude/rtk-misses.log (JSONL: {ts, cmd, bytes, exit_code})
# Threshold: 5KB stdout

set -euo pipefail

if ! command -v jq &>/dev/null; then exit 0; fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# Skip if command already uses rtk
case "${CMD}" in
  rtk\ *|*\ \|\ rtk\ *|*\&\&\ rtk\ *) exit 0 ;;
esac

# Skip trivial commands (matches fast-path in rtk-rewrite.sh)
case "${CMD%% *}" in
  true|false|:|pwd|exit|cd|export|unset|alias|unalias|history|hash|builtin|command|type|which|jobs|fg|bg|kill|echo|printf)
    exit 0 ;;
esac

STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // .tool_response.output // empty')
BYTES=${#STDOUT}

# Threshold: 5120 bytes (~1500 tokens)
if [ "$BYTES" -ge 5120 ]; then
  EC=$(echo "$INPUT" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0')
  jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg cmd "$CMD" \
    --argjson bytes "$BYTES" \
    --argjson ec "$EC" \
    '{ts: $ts, cmd: $cmd, bytes: $bytes, exit_code: $ec}' \
    >> "$HOME/.claude/rtk-misses.log" 2>/dev/null || true
fi

exit 0
