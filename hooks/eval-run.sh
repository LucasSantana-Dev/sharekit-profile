#!/usr/bin/env bash
# eval-run.sh — A/B task runner for the eval gate.
#
# Runs the eval-tasks.sh catalog against the target hooks and records results
# to eval-baseline.sh. This is the "run" half that produces the A/B data the
# gate reads.
#
# Variants:
#   with    — actually invoke the target hook on the task input; the run PASSES
#             if the hook's exit code matches the expected verdict
#             (block = exit 2, allow = exit 0). This measures harness-present
#             behavior.
#   without — simulate the harness ABSENT: always allow (exit 0). The run
#             PASSES only for tasks whose expected verdict is "allow". This is
#             the baseline: with no enforcement, every "block" case is a
#             failure (the dangerous command would have run).
#
# The lift = (with pass rate) - (without pass rate). For a correct harness,
# with >> without on block-expected tasks; the lift is positive. A regression
# (a hook stops blocking) collapses with toward without and the lift drops.
#
# Held-out enforcement (the load-bearing invariant):
#   --split seen     — proposer may use this to self-check its edits.
#   --split heldout  — RESERVED for the gate. The proposer NEVER runs heldout;
#                      running it here would let the proposer read expected
#                      verdicts and overfit. eval-run.sh rejects --split heldout
#                      unless --gate-authority is set (the gate passes it).
#
# Usage:
#   hooks/eval-run.sh --eval <name> --variant with  [--split seen|heldout|all] [--gate-authority]
#   hooks/eval-run.sh --eval <name> --variant without [--split seen|heldout|all]
#
# The eval set is initialized if missing. Results append to
# .harness/eval/<name>/runs.jsonl via eval-baseline.sh record.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/hooks"
EVAL_BASELINE="$HOOKS/eval-baseline.sh"
EVAL_TASKS="$HOOKS/eval-tasks.sh"

eval_name=""
variant=""
split="all"
gate_authority=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --eval) eval_name="$2"; shift 2 ;;
    --variant) variant="$2"; shift 2 ;;
    --split) split="$2"; shift 2 ;;
    --gate-authority) gate_authority=1; shift ;;
    *) echo "eval-run: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$eval_name" ]] || { echo "eval-run: --eval <name> required" >&2; exit 1; }
[[ "$variant" == "with" || "$variant" == "without" ]] || { echo "eval-run: --variant with|without required" >&2; exit 1; }
[[ "$split" == "seen" || "$split" == "heldout" || "$split" == "all" ]] || { echo "eval-run: --split seen|heldout|all" >&2; exit 1; }

# Held-out enforcement: only the gate (with --gate-authority) may run heldout.
if [[ "$split" == "heldout" && "$gate_authority" -eq 0 ]]; then
  echo "eval-run: REFUSED — --split heldout is reserved for the gate (evaluator-not-agent invariant)." >&2
  echo "  The proposer must never read held-out expected verdicts; it would overfit." >&2
  echo "  Run --split seen for proposer self-check, or pass --gate-authority from gate.sh." >&2
  exit 1
fi

# Initialize the eval set if missing.
if [[ ! -d "$ROOT/.harness/eval/$eval_name" ]]; then
  "$EVAL_BASELINE" init "$eval_name" >/dev/null
fi

# Run each task in the split.
pass_count=0
fail_count=0
while IFS= read -r task; do
  [[ -z "$task" ]] && continue
  tid="$(printf '%s' "$task" | jq -r '.id')"
  hook="$(printf '%s' "$task" | jq -r '.hook')"
  expected="$(printf '%s' "$task" | jq -r '.expected')"
  input="$(printf '%s' "$task" | jq -c '.input')"
  note="$(printf '%s' "$task" | jq -r '.note')"

  if [[ "$variant" == "without" ]]; then
    # Harness absent: always allow. Pass only if expected is "allow".
    actual="allow"
    if [[ "$expected" == "allow" ]]; then outcome="pass"; else outcome="fail"; fi
    ms=0
  else
    # Harness present: invoke the hook on the input, measure exit code + latency.
    start_ns="$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')"
    printf '%s' "$input" | bash "$HOOKS/$hook" >/dev/null 2>&1
    rc=$?
    end_ns="$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')"
    ms=$(( (end_ns - start_ns) / 1000000 ))
    # exit 2 = block, exit 0 = allow, anything else = unexpected -> treat as allow
    if [[ "$rc" -eq 2 ]]; then actual="block"; else actual="allow"; fi
    if [[ "$actual" == "$expected" ]]; then outcome="pass"; else outcome="fail"; fi
  fi

  if [[ "$outcome" == "pass" ]]; then pass_count=$((pass_count+1)); else fail_count=$((fail_count+1)); fi
  "$EVAL_BASELINE" record "$eval_name" "$variant" "$outcome" "$ms" "$tid:$note" >/dev/null
  printf '  %-22s %-7s expected=%-5s actual=%-5s %s\n' "$tid" "$variant" "$expected" "$actual" "$outcome"
done < <("$EVAL_TASKS" emit | jq -c --arg s "$split" 'if $s=="all" then . else select(.split==$s) end')

total=$((pass_count + fail_count))
echo "eval-run: $variant $split = $pass_count/$total pass"
