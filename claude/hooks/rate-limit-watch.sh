#!/usr/bin/env bash
# Stop hook: capture Anthropic rate-limit headers from the last turn's API call,
# write state file, emit systemMessage on band crossings.
# Standalone passive monitor — the manual companion skill /rate-limit-watch was
# retired 2026-06-06; this hook keeps running independently.
set -uo pipefail
command -v jq &>/dev/null || exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[[ -z "$SESSION_ID" ]] && exit 0

JSONL=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
[[ -f "$JSONL" ]] || exit 0

# Pull last line containing ratelimit headers
HEADERS_LINE=$(grep -h '"anthropic-ratelimit' "$JSONL" 2>/dev/null | tail -1 || true)
[[ -z "$HEADERS_LINE" ]] && exit 0

STATE="/tmp/claude-rate-limit-${SESSION_ID}.json"
LAST_BAND="/tmp/claude-rate-limit-band-${SESSION_ID}.txt"

remaining=$(printf '%s' "$HEADERS_LINE" | python3 -c '
import json, sys, time, re
line = sys.stdin.read()
try:
    d = json.loads(line)
except Exception:
    sys.exit(0)
headers = {}
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(k, str) and k.startswith("anthropic-ratelimit"):
                headers[k] = v
            walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(d)
if not headers: sys.exit(0)

out = {"timestamp": int(time.time()), "headers": headers}
keys_int = [
    "anthropic-ratelimit-requests-remaining",
    "anthropic-ratelimit-tokens-remaining",
    "anthropic-ratelimit-input-tokens-remaining",
    "anthropic-ratelimit-output-tokens-remaining",
]
for k in keys_int:
    v = headers.get(k)
    if v is not None:
        try: out[k.replace("anthropic-ratelimit-", "").replace("-", "_")] = int(v)
        except: pass

with open("'"$STATE"'", "w") as f: json.dump(out, f)

# Print the binding minimum for band check
vals = [out.get(k.replace("anthropic-ratelimit-", "").replace("-", "_"))
        for k in keys_int]
vals = [v for v in vals if isinstance(v, int)]
print(min(vals) if vals else 999999)
' 2>/dev/null)

[[ -z "$remaining" ]] && exit 0

last=$(cat "$LAST_BAND" 2>/dev/null || echo "999999")

emit() {
  local band=$1 msg=$2 should_block=$3
  if [[ "$last" -gt "$band" && "$remaining" -le "$band" ]]; then
    if [[ "$should_block" == "true" ]]; then
      # Highest band: emit decision:block with once-per-session guard
      BLOCK_FLAG="/tmp/claude-rate-limit-block-${SESSION_ID}"
      if [ ! -f "$BLOCK_FLAG" ]; then
        touch "$BLOCK_FLAG"
        jq -n --arg m "$msg" '{
          systemMessage: $m,
          hookSpecificOutput: {
            decision: "block",
            reason: ("RATE-LIMIT GUARD (act now, do not just acknowledge): " + $m + " Immediately: 1) wrap current work with /handoff to checkpoint state; 2) dispatch remaining heavy tasks to subagents via /dispatch; 3) pause bulk operations until the limit resets.")
          }
        }'
      else
        # Already blocked in this session; fall back to systemMessage only
        jq -n --arg m "$msg" '{"systemMessage": $m}'
      fi
    else
      # Lower bands: warn-only
      jq -n --arg m "$msg" '{"systemMessage": $m}'
    fi
    echo "$band" >"$LAST_BAND"
  fi
}

emit 10000 "[yellow] Rate-limit headroom low ($remaining units remaining). Consider /model sonnet for routine work." false
emit 3000  "[orange] Rate-limit headroom critical ($remaining units). Switch to /model sonnet or pause non-essential work." false
emit 500   "[red] Rate-limit imminent ($remaining units). Wrap with /handoff and pause." true

exit 0
