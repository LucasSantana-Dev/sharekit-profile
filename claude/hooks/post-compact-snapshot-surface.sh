#!/usr/bin/env bash
# post-compact-snapshot-surface.sh — PostCompact hook. After a compact fires,
# surface the most recent precompact_snapshot memory note (written by
# pre-compact-memory-snapshot.sh) so the assistant knows what durable decisions
# were captured BEFORE the compact dropped context.
#
# Without this, the snapshot lives on disk but the assistant doesn't know it
# exists until the next session start (when MEMORY.md is re-read).

set -uo pipefail
command -v jq &>/dev/null || exit 0

INPUT=$(cat 2>/dev/null || true)
SID=$(echo "$INPUT" | jq -r '.session_id // .sessionId // empty' 2>/dev/null)
[ -z "$SID" ] && SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$SID" ] && exit 0

# Project memory dir is sibling of session JSONL
JSONL=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SID}.jsonl" -type f 2>/dev/null | head -1)
[ -z "$JSONL" ] && exit 0
MEMORY_DIR="$(dirname "$JSONL")/memory"
[ -d "$MEMORY_DIR" ] || exit 0

# Find most recent precompact snapshot — within last 5 min (this compact's)
SNAP=$(find "$MEMORY_DIR" -maxdepth 1 -name 'precompact_snapshot_*.md' -mmin -5 -type f 2>/dev/null | sort | tail -1)
[ -z "$SNAP" ] && exit 0

# Extract description from frontmatter + count decision items
DESC=$(awk '/^description:/{sub(/^description: /,""); print; exit}' "$SNAP" 2>/dev/null)
COUNT=$(grep -c '^- \*\*\[' "$SNAP" 2>/dev/null || echo 0)

MSG=$(printf ' PreCompact snapshot saved before this compact\n\n- **File:** %s\n- **Captured:** %s decision/finding markers\n- **Description:** %s\n\nRead it if you need to recover specific decisions from earlier in this session.' "$SNAP" "$COUNT" "${DESC:-(no description)}")

jq -n --arg m "$MSG" '{"systemMessage": $m}' 2>/dev/null
