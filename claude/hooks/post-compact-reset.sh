#!/usr/bin/env bash
# PostCompact hook: reset turn counter baseline so /compact resets effective-turn count.
# Handles both session_id naming conventions and a no-session-id fallback.
set -uo pipefail
command -v jq &>/dev/null || exit 0
command -v python3 &>/dev/null || exit 0

INPUT=$(cat)

# Claude Code PostCompact may use session_id or sessionId
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // .sessionId // empty' 2>/dev/null)

reset_session() {
	local sid="$1" count="$2"
	echo "$count" >"/tmp/claude-turn-reset-${sid}.txt"
	echo "$count" >"/tmp/claude-turn-count-${sid}.txt"
	echo "0" >"/tmp/claude-turn-calls-${sid}.txt"
	rm -f "/tmp/claude-reads-${sid}.txt" \
		"/tmp/claude-read-dedup-${sid}.json" \
		"/tmp/claude-handoff-triggered-${sid}.txt" \
		"/tmp/claude-warn-last-${sid}.txt"
}

if [[ -z "$SESSION_ID" ]]; then
	# No session_id in event — reset all known sessions as a safe fallback
	echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PostCompact: no session_id in event, resetting all. payload: ${INPUT:0:200}" \
		>>/tmp/claude-compact-debug.log 2>/dev/null || true
	for count_file in /tmp/claude-turn-count-*.txt; do
		[[ -f "$count_file" ]] || continue
		sid=$(basename "$count_file" .txt | sed 's/^claude-turn-count-//')
		count=$(cat "$count_file" 2>/dev/null | tr -dc '0-9'); count=${count:-0}
		reset_session "$sid" "$count"
	done
	exit 0
fi

# Try to get count from JSONL; fall back to cached count if file not ready yet
JSONL=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
if [[ -n "$JSONL" && -f "$JSONL" ]]; then
	COUNT=$(
		python3 - "$JSONL" <<'EOF'
import json, sys
count = 0
try:
    with open(sys.argv[1]) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") == "assistant" and d.get("message", {}).get("usage"):
                count += 1
except Exception:
    pass
print(count)
EOF
	)
	[[ -z "$COUNT" ]] && COUNT=0
else
	# JSONL not available yet — fall back to cached turn count
	COUNT=$(cat "/tmp/claude-turn-count-${SESSION_ID}.txt" 2>/dev/null | tr -dc '0-9'); COUNT=${COUNT:-0}
fi

reset_session "$SESSION_ID" "$COUNT"
exit 0
