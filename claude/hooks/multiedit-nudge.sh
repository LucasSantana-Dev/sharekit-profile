#!/usr/bin/env bash
# PostToolUse hook: detect sequential Edit calls on the same file and nudge toward MultiEdit.
# Fires after Edit. Tracks the last edited file per session in /tmp.
# Exits 0 always — advisory only.

set -uo pipefail
command -v jq &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL" != "Edit" ]] && exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE" ]] && exit 0

LAST_EDIT_FILE="/tmp/claude-last-edit-${SESSION_ID}.txt"
SAME_FILE_COUNT="/tmp/claude-same-edit-count-${SESSION_ID}.txt"

# Read last edited file
last=""
[[ -f "$LAST_EDIT_FILE" ]] && last=$(<"$LAST_EDIT_FILE")

if [[ "$last" == "$FILE" ]]; then
	# Increment same-file counter
	count=$(cat "$SAME_FILE_COUNT" 2>/dev/null | tr -dc '0-9'); count=${count:-0}
	count=$((count + 1))
	echo "$count" >"$SAME_FILE_COUNT"

	if ((count >= 2)); then
		SHORT=$(basename "$FILE")
		jq -n \
			--arg f "$SHORT" \
			--argjson c "$((count + 1))" \
			'{"systemMessage": "[WARN] MULTIEDIT: You have edited \($f) \($c) times in a row. Each Edit = 1 subscription turn. Batch remaining changes into a single MultiEdit call to save turns."}'
	fi
else
	# New file — reset counter
	echo "$FILE" >"$LAST_EDIT_FILE"
	echo "0" >"$SAME_FILE_COUNT"
fi

exit 0
