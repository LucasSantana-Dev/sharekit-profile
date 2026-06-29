#!/usr/bin/env bash
# post-incident-adr.sh — Stop hook.
# Enforces the RULES.md "Post-incident capture" invariant: after any P0/P1
# failure, commit a root-cause artifact (ADR or incident-log entry) before the
# next task. This hook scans the trajectory log for errors recorded this
# session and, if any high-severity signals are present, emits a reminder and
# records an incident stub to be graduated by the distill.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRAJ="$ROOT/.harness/runtime/trajectory.jsonl"
INC="$ROOT/.harness/runtime/incidents.jsonl"
mkdir -p "$(dirname "$INC")"

[[ -f "$TRAJ" ]] || exit 0

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Count error/blocked outcomes in the last hour of trajectory entries.
recent="$(tail -n 200 "$TRAJ" 2>/dev/null)"
sev_count="$(printf '%s' "$recent" | jq -r 'select(.outcome=="error" or .outcome=="blocked") | .ts' 2>/dev/null | wc -l | tr -d ' ')"

if [[ "$sev_count" -ge 3 ]]; then
  jq -nc --arg ts "$ts" --argjson n "$sev_count" \
    '{ts: $ts, event: "post-incident-reminder", severity: "P1-candidate", error_count: $n, action: "commit root-cause artifact (ADR or incident-log) before next task (RULES.md)"}' \
    >> "$INC"
  echo "STOP reminder — ${sev_count} error/blocked tool outcomes this session." >&2
  echo "  Post-incident capture (RULES.md): commit a root-cause artifact before the next task." >&2
  echo "  Stub recorded at $INC; graduate it via the distill review protocol." >&2
fi

exit 0
