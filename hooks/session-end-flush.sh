#!/usr/bin/env bash
# session-end-flush.sh — SessionEnd hook.
# Closes the "observe" half of the flywheel: writes a session record summarizing
# the trajectory, then queues the session for the nightly distill (transcript
# mining → candidate learnings). Cross-wave evidence: gearbox sessionEnd,
# forge SessionEnd, agentic-stack auto_dream staging, lumos trajectory JSONL.
#
# The distill itself is host-agent reviewed (graduate/reject with required
# rationale) — never unattended. This hook only stages; it never mutates
# semantic memory directly. No rubber-stamping.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRAJ="$ROOT/.harness/runtime/trajectory.jsonl"
RUNTIME="$ROOT/.harness/runtime"
SESSIONS="$RUNTIME/sessions"
PENDING="$RUNTIME/pending-distill.jsonl"
mkdir -p "$SESSIONS"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
sid="session-${stamp}"

# Summarize this session from the trajectory tail (since the last session
# boundary marker). For simplicity, summarize the last 500 entries.
recent="$(tail -n 500 "$TRAJ" 2>/dev/null || true)"
total="$(printf '%s' "$recent" | jq -r 'select(.event=="tool-call") | .ts' 2>/dev/null | wc -l | tr -d ' ')"
errors="$(printf '%s' "$recent" | jq -r 'select(.event=="tool-call" and .outcome=="error") | .ts' 2>/dev/null | wc -l | tr -d ' ')"
blocked="$(printf '%s' "$recent" | jq -r 'select(.event=="tool-call" and .outcome=="blocked") | .ts' 2>/dev/null | wc -l | tr -d ' ')"
top_tools="$(printf '%s' "$recent" | jq -r 'select(.event=="tool-call") | .tool' 2>/dev/null | sort | uniq -c | sort -rn | head -5 | jq -R -s 'split("\n") | map(select(length>0)) | map(split(" ")) | map({count: (.[0]|tonumber), tool: .[1]})' 2>/dev/null || echo '[]')"

record="$(jq -nc \
  --arg sid "$sid" \
  --arg ts "$ts" \
  --argjson total "$total" \
  --argjson errors "$errors" \
  --argjson blocked "$blocked" \
  --argjson tools "$top_tools" \
  '{sid: $sid, ended_at: $ts, tool_calls: $total, errors: $errors, blocked: $blocked, top_tools: $tools}')"

printf '%s\n' "$record" > "$SESSIONS/${sid}.json"
printf '%s\n' "$record" >> "$SESSIONS/index.jsonl"

# Queue for the nightly distill. The distill reads pending entries and mines
# them for candidate learnings (26 lesson patterns, confidence-scored), which
# the host agent then graduates or rejects.
printf '%s\n' "$record" >> "$PENDING"

# Boundary marker in the trajectory so the next session's summary is scoped.
jq -nc --arg ts "$ts" --arg sid "$sid" \
  '{ts: $ts, event: "session-boundary", sid: $sid, direction: "end"}' >> "$TRAJ"

echo "SessionEnd: session record written to $SESSIONS/${sid}.json; queued for distill." >&2
exit 0
