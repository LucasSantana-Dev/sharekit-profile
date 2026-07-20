#!/usr/bin/env bash
# Bash PreToolUse wrapper:
# 1. Fast-path: skip trivial commands without spawning rtk (saves ~30ms each).
# 2. Skip commands listed in rtk-bypass.list (EC=3 ask-rules that would
#    silently drop in bypassPermissions — managed by rtk-health check.sh).
# 3. Otherwise delegate to rtk-rewrite.sh for token-saving rewrites.
#
# Kept separate from rtk-rewrite.sh because rtk integrity-checks its own hook.
set -euo pipefail

if ! command -v jq &>/dev/null; then
  exec "$HOME/.claude/hooks/rtk-rewrite.sh"
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

case "${CMD%% *}" in
  true|false|:|pwd|exit|cd|export|unset|alias|unalias|history|hash|builtin|command|type|which|jobs|fg|bg|kill)
    exit 0
    ;;
esac

BYPASS_FILE="$HOME/.claude/hooks/rtk-bypass.list"
if [ -f "$BYPASS_FILE" ]; then
  while IFS= read -r word; do
    [ -z "$word" ] && continue
    case "$word" in '#'*) continue ;; esac
    [ "${CMD%% *}" = "$word" ] && exit 0
    case "$CMD" in
      *"| $word "*|*"| $word"|*"|$word "*|*"|$word") exit 0 ;;
    esac
  done < "$BYPASS_FILE"
fi

echo "$INPUT" | "$HOME/.claude/hooks/rtk-rewrite.sh"
