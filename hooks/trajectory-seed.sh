#!/usr/bin/env bash
# trajectory-seed.sh — synthesize a small representative trajectory.
#
# The improve track (diagnose/distill/propose) needs trajectory fuel to act on.
# From a cold start the trajectory is empty and every improve step no-ops. This
# helper writes a small representative trajectory (mixed success/error/blocked
# tool-call events) so the loop is exercisable before any real session runs.
#
# This is COLD-START FUEL ONLY. Real sessions replace it: once
# trajectory-log.sh (PostToolUse) has written real events, do not re-seed —
# the seed would dilute real signal. The seed is idempotent: it refuses to
# overwrite an existing non-empty trajectory unless --force.
#
# Usage:
#   hooks/trajectory-seed.sh            # seed if trajectory is empty/missing
#   hooks/trajectory-seed.sh --force    # overwrite an existing trajectory
#   hooks/trajectory-seed.sh --status   # print event counts by outcome
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/.harness/runtime/trajectory.jsonl"
mkdir -p "$(dirname "$LOG")"

force=0
status_only=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --status) status_only=1 ;;
    *) echo "trajectory-seed: unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ $status_only -eq 1 ]]; then
  [[ -f "$LOG" ]] || { echo "no trajectory yet"; exit 0; }
  echo "trajectory: $(wc -l < "$LOG" | tr -d ' ') events"
  for o in success error blocked; do
    n="$(jq -r --arg o "$o" 'select(.outcome==$o) | .' "$LOG" 2>/dev/null | jq -s 'length' 2>/dev/null || echo 0)"
    echo "  $o: $n"
  done
  exit 0
fi

# Refuse to overwrite a real trajectory.
if [[ -f "$LOG" && -s "$LOG" && $force -eq 0 ]]; then
  count="$(wc -l < "$LOG" | tr -d ' ')"
  echo "trajectory-seed: trajectory already has $count event(s); refusing to overwrite."
  echo "  Real session data is present — seeding would dilute it. Use --force to override."
  exit 0
fi

# Seed a representative trajectory: a mix of success, error, and blocked events
# the diagnose step can cluster and the distill step can mine. Timestamps are
# spaced over the last hour so the cache-compatibility heuristic sees activity.
now_epoch="$(date +%s)"
emit() {
  # emit <offset_seconds> <tool> <outcome> <input> <response>
  local off="$1"; local tool="$2"; local outcome="$3"; local input="$4"; local resp="$5"
  local epoch=$((now_epoch - off))
  local ts
  ts="$(date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
  jq -nc --arg ts "$ts" --arg tool "$tool" --arg outcome "$outcome" \
       --arg input "$input" --arg resp "$resp" \
    '{ts: $ts, event: "tool-call", tool: $tool, outcome: $outcome, input: $input, response: $resp}' \
    >> "$LOG"
}

# A successful edit.
emit 3000 "Edit" "success" '{"file_path":"hooks/example.sh"}' '{"ok":true}'
# A blocked dangerous command (the enforcement hooks doing their job).
emit 2900 "Bash" "blocked" '{"command":"rm -rf /"}' 'BLOCKED by dangerousPattern'
# A repeated error (the diagnose step should cluster this as a blind-retry pattern).
emit 2800 "Bash" "error" '{"command":"npm test"}' '{"is_error":true,"stderr":"test suite failed"}'
emit 2750 "Bash" "error" '{"command":"npm test"}' '{"is_error":true,"stderr":"test suite failed"}'
emit 2700 "Bash" "error" '{"command":"npm test"}' '{"is_error":true,"stderr":"test suite failed"}'
# A successful read.
emit 2600 "Read" "success" '{"file_path":"README.md"}' '{"ok":true}'
# A blocked push to main.
emit 2500 "Bash" "blocked" '{"command":"git push origin main"}' 'BLOCKED by PR-automation-halt'
# A successful commit on a feature branch.
emit 2400 "Bash" "success" '{"command":"git commit -m feat: add thing"}' '{"ok":true}'

count="$(wc -l < "$LOG" | tr -d ' ')"
echo "trajectory-seed: wrote $count representative event(s) to $LOG"
echo "  real sessions will append to this; do not re-seed (--force to overwrite)."
