#!/usr/bin/env bash
# eval-baseline.sh — with-skill vs no-skill baseline measurement.
#
# The "evaluate" half of the flywheel. A proposer without telemetry + held-out
# eval is just guesswork (the explicit lesson from selftune vs "agents that
# save notes"). This gate makes improvement MEASURABLE: run a task with and
# without a skill/prompt/hook, compare outcomes, gate on measurable lift.
#
# Cross-wave basis: selftune `baseline`, meta-agent held-out split,
# harness-evolver Pareto selection.
#
# This is a LOCAL, zero-dependency harness (matches the repo's no-cloud
# posture). It does not call an LLM judge directly — it records A/B runs and
# computes pass/fail + latency deltas so the host agent (evaluator ≠ agent)
# can grade. Wire a stronger judge later if needed.
#
# Usage:
#   hooks/eval-baseline.sh init <name>             # create an eval set dir
#   hooks/eval-baseline.sh record <name> <variant> <pass|fail> <ms> [note]
#                                                   # variant = with|without|<custom>
#   hooks/eval-baseline.sh compare <name>          # show with vs without deltas
#   hooks/eval-baseline.sh gate <name> <threshold> # exit 0 if lift >= threshold
#
# Eval sets live in .harness/eval/<name>/ — gitignored runtime, but the
# DECISION to graduate a change is recorded in review-decisions.jsonl.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVAL="$ROOT/.harness/eval"
RUNTIME="$ROOT/.harness/runtime"
DECISIONS="$RUNTIME/review-decisions.jsonl"
mkdir -p "$EVAL" "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cmd="${1:-}"; shift || true
die() { echo "eval-baseline: $*" >&2; exit 1; }

case "$cmd" in
  init)
    name="${1:-}"; [[ -n "$name" ]] || die "init requires a <name>"
    d="$EVAL/$name"; mkdir -p "$d"
    : > "$d/runs.jsonl"
    echo "init: eval set '$name' at $d"
    echo "  record runs: hooks/eval-baseline.sh record $name <variant> <pass|fail> <ms>"
    ;;

  record)
    name="${1:-}"; variant="${2:-}"; outcome="${3:-}"; ms="${4:-}"; note="${5:-}"
    [[ -n "$name" && -n "$variant" && -n "$outcome" && -n "$ms" ]] \
      || die "record requires <name> <variant> <pass|fail> <ms> [note]"
    d="$EVAL/$name"; [[ -d "$d" ]] || die "eval set '$name' not found; run init first"
    printf '{"ts":"%s","variant":"%s","outcome":"%s","ms":%s,"note":"%s"}\n' \
      "$ts" "$variant" "$outcome" "$ms" "$note" >> "$d/runs.jsonl"
    echo "recorded: $name $variant $outcome ${ms}ms"
    ;;

  compare)
    name="${1:-}"; [[ -n "$name" ]] || die "compare requires a <name>"
    d="$EVAL/$name"; [[ -f "$d/runs.jsonl" ]] || die "no runs for '$name'"
    echo "compare: $name"
    for v in with without; do
      runs="$(jq -r --arg v "$v" 'select(.variant==$v)' "$d/runs.jsonl" 2>/dev/null)"
      n="$(printf '%s' "$runs" | jq -s 'length' 2>/dev/null || echo 0)"
      [[ "$n" -gt 0 ]] || { echo "  $v: 0 runs"; continue; }
      pass="$(printf '%s' "$runs" | jq -r 'select(.outcome=="pass")' | jq -s 'length' 2>/dev/null || echo 0)"
      rate="$(awk "BEGIN{printf \"%.2f\", $pass/$n}")"
      avg_ms="$(printf '%s' "$runs" | jq -s 'map(.ms) | add/length' 2>/dev/null | awk '{printf "%.0f", $1}' || echo 0)"
      echo "  $v: $pass/$n pass (${rate}), avg ${avg_ms}ms"
    done
    ;;

  gate)
    name="${1:-}"; thr="${2:-}"; [[ -n "$name" && -n "$thr" ]] || die "gate requires <name> <threshold>"
    d="$EVAL/$name"; [[ -f "$d/runs.jsonl" ]] || die "no runs for '$name'"
    # lift = (with pass rate) - (without pass rate)
    with_pass="$(jq -r 'select(.variant=="with" and .outcome=="pass")' "$d/runs.jsonl" | jq -s 'length' 2>/dev/null || echo 0)"
    with_n="$(jq -r 'select(.variant=="with")' "$d/runs.jsonl" | jq -s 'length' 2>/dev/null || echo 0)"
    without_pass="$(jq -r 'select(.variant=="without" and .outcome=="pass")' "$d/runs.jsonl" | jq -s 'length' 2>/dev/null || echo 0)"
    without_n="$(jq -r 'select(.variant=="without")' "$d/runs.jsonl" | jq -s 'length' 2>/dev/null || echo 0)"
    [[ "$with_n" -gt 0 && "$without_n" -gt 0 ]] || die "need >=1 run each for with and without"
    with_rate="$(awk "BEGIN{printf \"%.3f\", $with_pass/$with_n}")"
    without_rate="$(awk "BEGIN{printf \"%.3f\", $without_pass/$without_n}")"
    lift="$(awk "BEGIN{printf \"%.3f\", $with_rate - $without_rate}")"
    echo "gate: $name lift=$lift (with=$with_rate, without=$without_rate), threshold=$thr"
    awk "BEGIN{exit !($lift >= $thr)}" \
      && { echo "PASS — lift meets threshold"; printf '{"ts":"%s","event":"eval-gate","name":"%s","lift":%s,"threshold":%s,"result":"pass"}\n' "$ts" "$name" "$lift" "$thr" >> "$DECISIONS"; exit 0; } \
      || { echo "FAIL — lift below threshold"; printf '{"ts":"%s","event":"eval-gate","name":"%s","lift":%s,"threshold":%s,"result":"fail"}\n' "$ts" "$name" "$lift" "$thr" >> "$DECISIONS"; exit 1; }
    ;;

  *) die "unknown command: $cmd (use init|record|compare|gate)" ;;
esac
exit 0
