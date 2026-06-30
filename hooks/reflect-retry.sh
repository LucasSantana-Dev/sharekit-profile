#!/usr/bin/env bash
# reflect-retry.sh — inline retry-with-reflection (P9.2, Reflexion NeurIPS 2023).
#
# Per-task reflection on a gate FAIL, DISTINCT from the batch flywheel
# (propose.sh / distill.sh). Where the flywheel optimizes the harness across
# sessions, this hook produces a reflection on a SINGLE failed proposal so the
# next proposal retries WITH the reflection as context (the Reflexion pattern:
# on failure, generate a self-reflection, store it, retry with the reflection).
#
# Honors the resolved contradictions in docs/harness-research-synthesis.md:
#   - #1 Reflection vs forward-only: reflection for EVAL-GATED tasks only (a
#     gate FAIL is a clearly-detectable failure signal), NOT open-ended
#     exploration. This hook only fires on a gate FAIL.
#   - #2 Reflexion-for-all-tasks (do-not-adopt): bounded by a MAX RETRY cap.
#     After N=3 reflections on a target without an intervening gate PASS, the
#     hook refuses to write another reflection and instead parks the target
#     BLOCKED via dispatch.sh so a human intervenes. This is the Reflexion
#     max-retry bound — the loop does not spin forever.
#
# The reflection is ADVISORY: this hook never blocks (exit 0), never mutates
# memory, and never auto-applies. The reflection stages to
# .harness/forge/reflections/ for the host agent to review; propose.sh injects
# the latest reflection into its section 3.5 so the next proposal reads it.
#
# Usage:
#   hooks/reflect-retry.sh <target> <proposal-id> [fail-reasons]   # reflect on a gate FAIL
#   hooks/reflect-retry.sh --status                                # print the last reflection
#   hooks/reflect-retry.sh --count <target>                        # reflections since last gate PASS
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
REFLECTIONS="$FORGE/reflections"
HISTORY="$RUNTIME/iteration-history.jsonl"
TRAJ="$RUNTIME/trajectory.jsonl"
MAX_RETRIES=3
mkdir -p "$REFLECTIONS" "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- CLI: --status (print the last reflection) -------------------------------
if [[ "${1:-}" == "--status" ]]; then
  last="$(ls -t "$REFLECTIONS"/*.md 2>/dev/null | head -1)"
  [[ -n "$last" ]] || { echo "no reflections yet"; exit 0; }
  bat -p "$last" 2>/dev/null || cat "$last"
  exit 0
fi

# --- CLI: --count <target> (reflections since the last gate PASS) ------------
if [[ "${1:-}" == "--count" ]]; then
  target="${2:-}"
  [[ -n "$target" ]] || { echo "reflect-retry --count: requires <target>" >&2; exit 2; }
  [[ -f "$HISTORY" ]] || { echo "0"; exit 0; }
  # Walk the history backwards from the most recent entry for this target.
  # Count reflections (status=reflected) until a gate PASS (status=gated) is
  # hit; that PASS resets the retry counter (an intervening success means the
  # next failure is a fresh reflection cycle, not a continuation).
  count="$(tac "$HISTORY" 2>/dev/null | jq -c --arg t "$target" 'select(.target==$t)' 2>/dev/null \
    | awk -v RS='\n' '
      /"status":"gated"/ { exit }
      /"status":"reflected"/ { c++ }
      END { print c+0 }')"
  echo "$count"
  exit 0
fi

target="${1:-}"
pid="${2:-}"
fail_reasons="${3:-}"
[[ -n "$target" ]] || { echo "reflect-retry: requires <target> [proposal-id] [fail-reasons]" >&2; exit 2; }

# --- Max-retry cap (the Reflexion bound) -------------------------------------
# If the target already has MAX_RETRIES reflections without an intervening gate
# PASS, refuse to write another. The loop must not spin forever; a human
# intervenes. The caller (cycle.sh) parks the target BLOCKED via dispatch.sh.
prior_count="$(bash "$0" --count "$target" 2>/dev/null || echo 0)"
if [[ "$prior_count" -ge "$MAX_RETRIES" ]]; then
  echo "reflect-retry: MAX RETRY CAP hit for $target ($prior_count reflections without a gate PASS)" >&2
  echo "  refusing to write another reflection; the target needs human intervention." >&2
  echo "  (cycle.sh should park this target BLOCKED via dispatch.sh --block)" >&2
  exit 0
fi

# --- Gather the failure context ----------------------------------------------
# The latest gate-rejected / regressed iteration for this target is the failure
# under reflection. Prefer the caller-supplied fail_reasons; fall back to the
# latest history note (the gate records fail_reasons there) + the iteration
# history WHY digest so the reflection addresses root cause, not symptom.
fail_note="$fail_reasons"
if [[ -z "$fail_note" ]]; then
  fail_note="$(bash "$ROOT/hooks/history.sh" last "$target" 2>/dev/null | jq -r '.note // empty' 2>/dev/null)"
fi
why_digest=""
[[ -f "$HISTORY" ]] && why_digest="$(bash "$ROOT/hooks/history.sh" why "$target" 2>/dev/null)"

# The latest transcript scan (if any) adds systemic-pattern context.
last_scan="$(ls -t "$FORGE"/*transcript-scan*.md 2>/dev/null | head -1)"
scan_summary=""
if [[ -n "$last_scan" && -f "$last_scan" ]]; then
  scan_summary="$(grep -E '^- (refusals|evaluation-awareness|environment-drift|hallucination|excessive-agency|prompt-injection)' "$last_scan" 2>/dev/null | head -6)"
fi

digest="$REFLECTIONS/${ts//[:]/-}-reflection.md"
machine="$REFLECTIONS/${ts//[:]/-}-reflection.jsonl"

# --- Write the structured reflection -----------------------------------------
# The four-field structure is the Reflexion reflection template. The proposing
# model / host agent fills the analysis; this hook assembles the context.
{
  printf '# Reflection — %s\n\n' "$ts"
  printf 'Per-task reflection on a gate FAIL for `%s` (proposal `%s`).\n' "$target" "${pid:-<none>}"
  printf 'This is an inline retry-with-reflection (Reflexion, NeurIPS 2023): the next\n'
  printf 'proposal for this target will read this reflection as context (propose.sh\n'
  printf 'section 3.5) and retry WITH the reflection, not blind. Distinct from the\n'
  printf 'batch flywheel (propose.sh / distill.sh).\n\n'
  printf 'Retry count for this target (since last gate PASS): %s / %s\n\n' "$prior_count" "$MAX_RETRIES"

  printf '## Failure context\n\n'
  printf -- '- target: `%s`\n' "$target"
  printf -- '- proposal: `%s`\n' "${pid:-<none>}"
  printf -- '- fail reasons: %s\n\n' "${fail_note:-<none recorded>}"

  if [[ -n "$why_digest" ]]; then
    printf '## Prior iteration history (the WHY)\n\n'
    printf '```\n%s\n```\n\n' "$why_digest"
  fi

  if [[ -n "$scan_summary" ]]; then
    printf '## Latest transcript-scan signals (systemic context)\n\n'
    printf '%s\n\n' "$scan_summary"
  fi

  printf '## Reflection (Reflexion template — fill in)\n\n'
  printf '> The proposing model / host agent fills these four fields. Read the failure\n'
  printf '> context + history above first; do not repeat dead ends the history already\n'
  printf '> records.\n\n'
  printf -- '- **what_failed**: \n'
  printf -- '- **why**: \n'
  printf -- '- **what_to_avoid**: \n'
  printf -- '- **what_to_try_next**: \n\n'

  printf '## How this reflection is used\n\n'
  printf 'propose.sh injects this reflection into section 3.5 of the next proposal for\n'
  printf '`%s`, so the proposing model retries WITH the reflection as context. After\n' "$target"
  printf '%s reflections without an intervening gate PASS, reflect-retry.sh refuses to\n' "$MAX_RETRIES"
  printf 'write another and the target is parked BLOCKED for human intervention.\n'
} > "$digest"

# --- Write machine-readable reflection event ---------------------------------
{
  printf '{"ts":"%s","event":"reflection","target":"%s","proposal_id":"%s","retry_count":%s,"max_retries":%s,"fail_reasons":"%s"}\n' \
    "$ts" "$target" "${pid:-}" "$prior_count" "$MAX_RETRIES" "${fail_note//\"/\\\"}"
} >> "$machine"

# --- Append a reflection event to the trajectory (the observe log) -----------
# So the flywheel's observe half records that a reflection happened (the next
# distill/diagnose pass sees it).
if [[ -f "$TRAJ" ]]; then
  printf '{"ts":"%s","event":"reflection","tool":"reflect-retry.sh","outcome":"reflected","target":"%s","proposal_id":"%s","retry_count":%s}\n' \
    "$ts" "$target" "${pid:-}" "$prior_count" >> "$TRAJ"
fi

# --- Record the reflection in iteration history ------------------------------
# status=reflected so --count can find it (it counts status=reflected since the
# last status=gated). This is the non-Markovian trail.
bash "$ROOT/hooks/history.sh" add "$target" "${pid:-reflection-$ts}" "reflected" "retry" "$prior_count" \
  "reflection staged at $digest (retry $prior_count/$MAX_RETRIES)" 2>/dev/null || true

echo "reflection staged: $digest"
echo "  target: $target | retry $((prior_count + 1))/$MAX_RETRIES"
echo "  next proposal for this target will read it via propose.sh section 3.5"
exit 0
