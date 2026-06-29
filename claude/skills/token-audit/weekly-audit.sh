#!/usr/bin/env bash
# Weekly token audit with cache health alert
# Runs via LaunchAgent every Monday. Sends macOS notification if cache hit rate < 90%.
# Logs summary to ~/.claude/token-audit-weekly.log

set -uo pipefail

# Ensure python3 is available
if ! command -v python3 &>/dev/null; then
	echo "ERROR: python3 not found in PATH" >&2
	exit 0
fi

# Run the audit for the last 7 days in JSON format
AUDIT_JSON=$(python3 ~/.claude/skills/token-audit/audit.py --days 7 --json 2>&1)

if [[ -z "$AUDIT_JSON" ]]; then
	echo "ERROR: audit.py produced no output" >&2
	exit 0
fi

# Parse JSON output to extract cache metrics
CACHE_READ=$(echo "$AUDIT_JSON" | python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('aggregate', {}).get('cache_read', 0))" 2>/dev/null || echo "0")
CACHE_WRITE=$(echo "$AUDIT_JSON" | python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('aggregate', {}).get('cache_write', 0))" 2>/dev/null || echo "0")
SESSION_COUNT=$(echo "$AUDIT_JSON" | python3 -c "import sys, json; d = json.load(sys.stdin); print(len(d.get('sessions', [])))" 2>/dev/null || echo "0")
TURN_COUNT=$(echo "$AUDIT_JSON" | python3 -c "import sys, json; d = json.load(sys.stdin); print(sum(len(s.get('turns', [])) for s in d.get('sessions', [])))" 2>/dev/null || echo "0")
TOTAL_COST=$(echo "$AUDIT_JSON" | python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('aggregate', {}).get('cost', 0))" 2>/dev/null || echo "0")

# Compute cache hit rate
TOTAL_CACHE=$((CACHE_READ + CACHE_WRITE))
if [[ $TOTAL_CACHE -gt 0 ]]; then
	HIT_RATE=$(python3 -c "print(int(100 * $CACHE_READ / $TOTAL_CACHE))" 2>/dev/null || echo "0")
else
	HIT_RATE=0
fi

# Log the summary
LOG_FILE="$HOME/.claude/token-audit-weekly.log"
mkdir -p "$(dirname "$LOG_FILE")"
{
	printf "%s | sessions: %s | turns: %s | cost: \$%.2f | cache_hit_rate: %d%%\n" \
		"$(date +'%Y-%m-%d %H:%M:%S')" \
		"$SESSION_COUNT" \
		"$TURN_COUNT" \
		"$TOTAL_COST" \
		"$HIT_RATE"
} >>"$LOG_FILE"

# Alert if cache hit rate drops below 90%
if [[ $HIT_RATE -lt 90 ]]; then
	osascript -e "display notification \"Cache hit rate: ${HIT_RATE}% (normal: 97%+). Check for Anthropic caching changes.\" with title \"Claude Code: Cache Alert\""
fi

exit 0
