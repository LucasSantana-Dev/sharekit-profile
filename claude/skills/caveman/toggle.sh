#!/usr/bin/env bash
# caveman toggle — flip terse-output mode for the current session.
# Called from the /caveman skill invocation.
#
# Usage: toggle.sh [on|off|status]   (default: toggle current state)

set -euo pipefail
SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$SID" ] && { echo "no CLAUDE_CODE_SESSION_ID — can't track state" >&2; exit 1; }

STATE_DIR="$HOME/.claude/state/caveman"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$SID"

current_state() {
  [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "off"
}

ACTION="${1:-toggle}"
CUR=$(current_state)

case "$ACTION" in
  on)     NEW="on"  ;;
  off)    NEW="off" ;;
  status) echo "caveman: $CUR"; exit 0 ;;
  toggle) [ "$CUR" = "on" ] && NEW="off" || NEW="on" ;;
  *)      echo "usage: $0 [on|off|status|toggle]" >&2; exit 2 ;;
esac

echo "$NEW" > "$STATE_FILE"
if [ "$NEW" = "on" ]; then
  echo "caveman: ON  (output mode terse — no preamble, no recap, code-only)"
else
  echo "caveman: OFF (output mode normal)"
fi
