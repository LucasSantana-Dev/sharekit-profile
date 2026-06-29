#!/usr/bin/env bash
# trajectory-log.sh — PostToolUse hook.
# The "observe" half of the self-improvement flywheel. Every tool call is
# appended as a structured JSONL event to .harness/runtime/trajectory.jsonl.
# The nightly distill + eval gate read this log to detect missed triggers,
# repeated failures, and token-waste patterns. Nothing blocks here — this is
# pure observation, the fuel for evaluate → optimize.
#
# Cross-wave evidence: gearbox self-learning.mjs, lumos TrajectoryLogger (JSONL),
# agentic-stack episodic memory, AHE NexAU step-level trace. The meta-harness
# result is that non-Markovian full-history search (reading WHY things failed)
# beats best-of-N — but it requires the trace to exist. This hook creates it.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/.harness/runtime/trajectory.jsonl"
mkdir -p "$(dirname "$LOG")"

input="$(cat)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
tool_input="$(printf '%s' "$input" | jq -c '.tool_input // empty' 2>/dev/null || echo 'null')"
tool_response="$(printf '%s' "$input" | jq -c '.tool_response // .tool_result // empty' 2>/dev/null || echo 'null')"
# Truncate large payloads so the log stays cheap.
tool_input_trim="$(printf '%s' "$tool_input" | head -c 2048)"
tool_response_trim="$(printf '%s' "$tool_response" | head -c 2048)"

# Heuristic outcome tag: success / error / blocked.
outcome="success"
if printf '%s' "$tool_response" | grep -Eqi '"is_error":true|"error":|"stderr":"[^"]*error'; then
  outcome="error"
fi
if printf '%s' "$tool_response" | grep -Eqi 'BLOCKED|exit code 2'; then
  outcome="blocked"
fi

jq -nc \
  --arg ts "$ts" \
  --arg tool "$tool_name" \
  --arg outcome "$outcome" \
  --arg input "$tool_input_trim" \
  --arg resp "$tool_response_trim" \
  '{ts: $ts, event: "tool-call", tool: $tool, outcome: $outcome, input: $input, response: $resp}' \
  >> "$LOG"

exit 0
