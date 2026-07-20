#!/usr/bin/env bash
# PostToolUse hook: count assistant turns per session and trigger periodic handoffs.
# Autocompact (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=90) does the actual compaction;
# this hook only saves handoffs and emits informational notices at 500 / 1000 turns.
# Fires on every tool use. Reads turn count from session JSONL — no external state.
# Exits 0 always; uses systemMessage to communicate with Claude. Never blocks.

set -uo pipefail
command -v jq &>/dev/null || exit 0
command -v python3 &>/dev/null || exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# Count every N tool calls (not every single one — too expensive)
CALL_CACHE="/tmp/claude-turn-calls-${SESSION_ID}.txt"
TURN_CACHE="/tmp/claude-turn-count-${SESSION_ID}.txt"
RESET_FILE="/tmp/claude-turn-reset-${SESSION_ID}.txt"
CHECK_INTERVAL=10

# Increment call counter (sanitized read + atomic write: concurrent PostToolUse invocations
# from parallel subagents can catch the file mid-truncate and feed garbage into arithmetic)
calls=$(cat "$CALL_CACHE" 2>/dev/null | tr -dc '0-9'); calls=${calls:-0}
calls=$((calls + 1))
tmp="${CALL_CACHE}.$$"; echo "$calls" >"$tmp" && mv -f "$tmp" "$CALL_CACHE"

# Only recount turns every CHECK_INTERVAL tool calls
if ((calls % CHECK_INTERVAL != 0)); then
	# Still check cached turn count for alerts
	[[ ! -f "$TURN_CACHE" ]] && exit 0
	# Freshness guard: if /compact ran after the last cache write, the cache is stale — skip it
	if [[ -f "$RESET_FILE" && "$RESET_FILE" -nt "$TURN_CACHE" ]]; then
		exit 0
	fi
	turn_count=$(cat "$TURN_CACHE" 2>/dev/null | tr -dc '0-9')
else
	# Find JSONL and count assistant turns
	JSONL=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
	[[ -z "$JSONL" || ! -f "$JSONL" ]] && exit 0

	turn_count=$(
		python3 - "$JSONL" <<'EOF'
import json, sys
path = sys.argv[1]
count = 0
try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") == "assistant" and d.get("message", {}).get("usage"):
                count += 1
    print(count)
except Exception:
    print(0)
EOF
	)
	echo "$turn_count" >"$TURN_CACHE"
fi

turn_count=${turn_count:-0}

# Subtract post-compact baseline so /compact resets the counter
baseline=$(cat "$RESET_FILE" 2>/dev/null | tr -dc '0-9'); baseline=${baseline:-0}
effective_count=$((turn_count - baseline))
[[ $effective_count -lt 0 ]] && effective_count=0

# Thresholds (against effective turns since last compact)
turn_count=$effective_count

# Auto-save handoff periodically (informational only — autocompact at 90% handles compaction)
# Trigger handoff at 300 turns since last compact, and once more at 800.
HANDOFF_LOCK="/tmp/claude-handoff-triggered-${SESSION_ID}.txt"
last_handoff=$(cat "$HANDOFF_LOCK" 2>/dev/null | tr -dc '0-9'); last_handoff=${last_handoff:-0}

if ((turn_count >= 300 && turn_count - last_handoff >= 500)); then
	echo "$turn_count" >"$HANDOFF_LOCK"
	HOOK_DIR="$(dirname "$0")"
	echo "$INPUT" | bash "$HOOK_DIR/pre-compact-summary.sh" >>/tmp/claude-auto-handoff.log 2>&1 &
fi

# Informational nudges — fire ONCE per band, never repeat.
# Autocompact (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=90) handles actual compaction; this is just visibility.
WARN_LAST_FILE="/tmp/claude-warn-last-${SESSION_ID}.txt"
last_warned=$(cat "$WARN_LAST_FILE" 2>/dev/null | tr -dc '0-9'); last_warned=${last_warned:-0}

# Bands: 500 (info), 1000 (long-session reminder). Above 1000, silent.
if ((turn_count >= 1000 && last_warned < 1000)); then
	jq -n --argjson t "$turn_count" \
		'{"systemMessage": "ℹ Long session: \($t) turns. Auto-compact at 90% context handles this; no manual action needed. Consider /handoff if switching tasks."}'
	echo 1000 >"$WARN_LAST_FILE"
elif ((turn_count >= 500 && last_warned < 500)); then
	jq -n --argjson t "$turn_count" \
		'{"systemMessage": "ℹ Session at \($t) turns. Handoff snapshots saved automatically. No action needed."}'
	echo 500 >"$WARN_LAST_FILE"
fi

exit 0
