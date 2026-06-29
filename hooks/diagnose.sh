#!/usr/bin/env bash
# diagnose.sh — self-diagnosis + failure clustering on the trajectory log.
#
# The "diagnose" half of the flywheel. Without this, the observe log is a fire
# hose with no signal. This script clusters failures, surfaces root-cause
# candidates, and detects the three anti-patterns that the cross-wave research
# flagged as the real drainers of "optimal results on any model":
#
#   1. MISSED TRIGGERS — a skill/hook that should have fired but didn't
#      (meta-harness: the #1 win is closed-loop trigger coverage).
#   2. REPEATED ERRORS — same tool + same error signature N times in a session.
#      Non-Markovian history is wasted if the agent re-tries blindly; the
#      meta-harness result is that reading WHY things failed beats best-of-N.
#   3. TOKEN-WASTE PATTERNS — tool responses repeatedly >2KB (lost-in-the-
#      middle), or a single tool called >20x in one window (contextweaver 92.2%
#      route-prompt reduction, agentforge cache boundary).
#
# Cross-wave basis: SkillForge self-diagnosis, AHE Agent Debugger (distill traces
# into sourced digests), meta-harness non-Markovian full-history search.
#
# Output: a human/agent-readable digest at .harness/runtime/diagnosis-<ts>.md
# plus a machine-readable .jsonl. NEVER mutates semantic memory — the host agent
# reviews and graduates findings via review.sh, same as distill candidates.
#
# Usage:
#   hooks/diagnose.sh                # scan the trajectory log, write digest
#   hooks/diagnose.sh --since <iso>  # only events after <iso>
#   hooks/diagnose.sh --status       # print last diagnosis summary, exit 0
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
LOG="$RUNTIME/trajectory.jsonl"
FORGE="$ROOT/.harness/forge"
mkdir -p "$RUNTIME" "$FORGE"

since=""
status_only=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) since="$2"; shift 2 ;;
    --status) status_only=1; shift ;;
    *) echo "diagnose: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ $status_only -eq 1 ]]; then
  last="$(ls -t "$RUNTIME"/diagnosis-*.md 2>/dev/null | head -1)"
  [[ -n "$last" ]] || { echo "no diagnosis yet"; exit 0; }
  bat -p "$last" 2>/dev/null || cat "$last"
  exit 0
fi

[[ -f "$LOG" ]] || { echo "diagnose: no trajectory log at $LOG (run some tool calls first)"; exit 0; }

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
date_tag="$(date -u +%Y-%m-%d)"
digest="$RUNTIME/diagnosis-${ts//[:]/-}.md"
machine="$RUNTIME/diagnosis-${ts//[:]/-}.jsonl"

# Filter by --since if given.
filter='.'
[[ -n "$since" ]] && filter=".ts > \"$since\""
events="$(jq -c --argjson s "$since" 'select(.ts > $s)' "$LOG" 2>/dev/null)"
# The jq above with empty string passes everything; with a real iso filters.
if [[ -n "$since" ]]; then
  events="$(jq -c --arg s "$since" 'select(.ts > $s)' "$LOG" 2>/dev/null)"
else
  events="$(jq -c '.' "$LOG" 2>/dev/null)"
fi

total="$(printf '%s' "$events" | jq -s 'length' 2>/dev/null || echo 0)"
[[ "$total" -gt 0 ]] || { echo "diagnose: trajectory log is empty"; exit 0; }

# --- Cluster 1: repeated errors (same tool + error signature) ---------------
repeated="$(printf '%s' "$events" \
  | jq -r 'select(.outcome=="error") | "\(.tool)\t\(.response[0:120])"' 2>/dev/null \
  | sort | uniq -c | sort -rn | awk '$1 >= 2 {print}')"

# --- Cluster 2: token-waste (response payloads > 2048 chars trimmed = full) --
#   and single-tool call-count per session > 20 ------------------------------
big_resp="$(printf '%s' "$events" \
  | jq -r 'select((.response|length) >= 1800) | "\(.tool)\t\(.ts)"' 2>/dev/null \
  | sort | uniq -c | sort -rn | head -10)"
tool_freq="$(printf '%s' "$events" \
  | jq -r '.tool' 2>/dev/null \
  | sort | uniq -c | sort -rn | awk '$1 >= 20 {print}')"

# --- Cluster 3: blocked outcomes (hooks halting the agent) ------------------
blocked="$(printf '%s' "$events" \
  | jq -r 'select(.outcome=="blocked") | "\(.ts)\t\(.tool)\t\(.response[0:120])"' 2>/dev/null)"

# --- Missed-trigger heuristic: blind retry ---------------------------------
# A success on a tool immediately following an error on the SAME tool = the
# agent retried without consulting WHY it failed (non-Markovian history ignored).
blind_retry=0
if [[ -n "$events" ]]; then
  # Count transitions error→success on the same tool (blind retry).
  blind_retry="$(printf '%s' "$events" \
    | jq -s -r 'group_by(.tool)[] | [ .[] ] as $arr | reduce range(1; length) as $i (0; if ($arr[$i-1].outcome // "") == "error" and ($arr[$i].outcome // "") == "success" then . + 1 else . end) // 0' 2>/dev/null \
    | awk '{s+=$1} END{print s+0}')"
fi

# --- Write machine-readable clusters -----------------------------------------
{
  printf '{"ts":"%s","event":"diagnosis","total_events":%s,"blind_retries":%s}\n' "$ts" "$total" "$blind_retry"
  printf '%s' "$repeated" | while IFS=$'\t' read -r count tool sig; do
    [[ -n "$count" ]] || continue
    printf '{"ts":"%s","event":"cluster","kind":"repeated-error","tool":"%s","count":%s,"signature":"%s"}\n' \
      "$ts" "${tool:-?}" "${count:-0}" "${sig:-}"
  done
  printf '%s' "$tool_freq" | while read -r count tool; do
    [[ -n "$count" ]] || continue
    printf '{"ts":"%s","event":"cluster","kind":"tool-overuse","tool":"%s","count":%s}\n' \
      "$ts" "${tool:-?}" "${count:-0}"
  done
  [[ -n "$blocked" ]] && while IFS=$'\t' read -r bts tool sig; do
    [[ -n "$bts" ]] || continue
    printf '{"ts":"%s","event":"cluster","kind":"blocked","tool":"%s","at":"%s","signature":"%s"}\n' \
      "$ts" "${tool:-?}" "${bts:-}" "${sig:-}"
  done <<< "$blocked"
} >> "$machine"

# --- Write human/agent-readable digest ---------------------------------------
{
  printf '# Self-Diagnosis — %s\n\n' "$ts"
  printf 'Trajectory log: `%s`\n' "$LOG"
  printf 'Events scanned: %s' "$total"
  [[ -n "$since" ]] && printf ' (since %s)' "$since"
  printf '\n\n'
  printf '## Repeated errors (same tool + signature)\n\n'
  if [[ -n "$repeated" ]]; then
    printf 'Count | Tool | Signature\n'
    printf -- '-----|------|----------\n'
    printf '%s\n' "$repeated" | while IFS=$'\t' read -r count tool sig; do
      [[ -n "$count" ]] || continue
      printf '%s | %s | %s\n' "${count:-0}" "${tool:-?}" "${sig:-}"
    done
  else
    printf 'None. No tool errored twice with the same signature.\n'
  fi
  printf '\n## Tool overuse (>20 calls in window)\n\n'
  if [[ -n "$tool_freq" ]]; then
    printf 'Count | Tool\n'
    printf -- '-----|------\n'
    printf '%s\n' "$tool_freq" | while read -r count tool; do
      [[ -n "$count" ]] || continue
      printf '%s | %s\n' "${count:-0}" "${tool:-?}"
    done
  else
    printf 'None. No single tool exceeded 20 calls.\n'
  fi
  printf '\n## Blocked outcomes (hooks halted the agent)\n\n'
  if [[ -n "$blocked" ]]; then
    printf '%s\n' "$blocked"
  else
    printf 'None. No blocked tool calls in this window.\n'
  fi
  printf '\n## Token-waste signals (large responses)\n\n'
  if [[ -n "$big_resp" ]]; then
    printf 'Count | Tool | Sample ts\n'
    printf -- '-----|------|----------\n'
    printf '%s\n' "$big_resp"
  else
    printf 'None. No responses near the 2KB trim ceiling.\n'
  fi
  printf '\n## Blind-retry estimate\n\n'
  printf '%s — heuristic count of a successful call immediately following an error on the SAME tool (non-Markovian history not consulted).\n' "$blind_retry"
  printf '\n## Recommended actions\n\n'
  printf -- '- If repeated errors: distill a lesson via `hooks/distill.sh`, then graduate with rationale.\n'
  printf -- '- If tool overuse: consider a bounded tool shortlist / ChoiceCard hook (contextweaver pattern).\n'
  printf -- '- If blocked outcomes: confirm the blocking hook is correct; if a guard is too strict, reopen it.\n'
  printf -- '- If blind retries >0: the agent is not reading WHY it failed — strengthen the reinject-on-error path.\n'
  printf '\nMachine-readable clusters: `%s`\n' "$machine"
} > "$digest"

echo "diagnosis written: $digest"
echo "  total events: $total | blind retries: $blind_retry"
[[ -n "$repeated" ]] && echo "  repeated errors: $(printf '%s\n' "$repeated" | wc -l | tr -d ' ')"
[[ -n "$tool_freq" ]] && echo "  overused tools: $(printf '%s\n' "$tool_freq" | wc -l | tr -d ' ')"
[[ -n "$blocked" ]] && echo "  blocked calls: $(printf '%s\n' "$blocked" | wc -l | tr -d ' ')"
exit 0
