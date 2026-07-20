#!/usr/bin/env bash
# PreToolUse hook: warn when Claude reads the same file 3+ times in a session.
# Fires before Read tool calls. State stored in /tmp per session.
# Exits 0 always — advisory only, never blocks.

set -uo pipefail
command -v jq &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL" != "Read" ]] && exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE" ]] && exit 0

# Track read counts in a simple key=count file
READ_LOG="/tmp/claude-reads-${SESSION_ID}.txt"
touch "$READ_LOG"

# Get current count for this file (grep -c exits 1 on no match; assign separately)
count=$(grep -c "^${FILE}$" "$READ_LOG" 2>/dev/null) || count=0
echo "$FILE" >>"$READ_LOG"
count=$((count + 1))

# Warn on 3rd+ read — advisory only, never blocks
if ((count >= 3)); then
	SHORT=$(basename "$FILE")
	jq -n \
		--arg f "$SHORT" \
		--argjson c "$count" \
		'{"systemMessage": "[WARN] REPEAT READ ×\($c): \($f) is already in your context — use your memory instead of re-reading."}'
fi

exit 0
