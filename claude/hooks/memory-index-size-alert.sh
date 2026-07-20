#!/usr/bin/env bash
# memory-index-size-alert.sh — SessionStart hook. Emits a systemMessage when
# any project MEMORY.md exceeds 40 entries (proxy: line count). Suggests
# running `/memory-prune` to keep the always-loaded index lean.
#
# Threshold: 40 lines (entries are roughly one-per-line bullets).
# Fires at most once per session per project (state file).

set -uo pipefail

STATE_DIR="$HOME/.claude/state/memory-size-alert"
mkdir -p "$STATE_DIR"

ALERTS=""
for MD in "$HOME"/.claude/projects/*/memory/MEMORY.md; do
  [ -f "$MD" ] || continue
  LINES=$(wc -l < "$MD" 2>/dev/null | tr -d ' ')
  [ -z "$LINES" ] && continue
  if [ "$LINES" -gt 40 ]; then
    PROJ=$(basename "$(dirname "$(dirname "$MD")")")
    # Once-per-day-per-project throttle
    STATE_FILE="$STATE_DIR/$PROJ-$(date -u +%Y-%m-%d)"
    [ -f "$STATE_FILE" ] && continue
    touch "$STATE_FILE"
    ALERTS="${ALERTS}- \`$PROJ\`: **${LINES} lines** in MEMORY.md\n"
  fi
done

[ -z "$ALERTS" ] && exit 0

MSG=$(printf ' Memory index growing — consider pruning\n\n%b\nIndex loads on every session start. When it exceeds 40 entries, run `/memory-prune` to archive stale notes (PR merged, file moved, gotcha patched). Fires once/day per project.' "$ALERTS")

# Emit with additionalContext directive to agent to act (run /memory-prune before other work)
STATE_DIR="$HOME/.claude/.state"; mkdir -p "$STATE_DIR"
PRUNE_FLAG="$STATE_DIR/memory-prune-$(date -u +%Y%m%d)"   # date-keyed: once/day, collision-free (was /tmp + weak 4-digit id)
if [ ! -f "$PRUNE_FLAG" ]; then
  touch "$PRUNE_FLAG"
  jq -n --arg m "$MSG" '{
    systemMessage: $m,
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "MEMORY INDEX ALERT (act now, do not just acknowledge): your memory index exceeds the lean-loading threshold. Before starting other work this session, run /memory-prune to archive stale entries and keep the always-loaded index performant."
    }
  }' 2>/dev/null || \
    python3 -c "import json,sys; print(json.dumps({'systemMessage': sys.argv[1], 'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': 'MEMORY INDEX ALERT (act now, do not just acknowledge): your memory index exceeds the lean-loading threshold. Before starting other work this session, run /memory-prune to archive stale entries and keep the always-loaded index performant.'}}))" "$MSG"
else
  jq -n --arg m "$MSG" '{"systemMessage": $m}' 2>/dev/null || \
    python3 -c "import json,sys; print(json.dumps({'systemMessage': sys.argv[1]}))" "$MSG"
fi
