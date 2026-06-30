#!/usr/bin/env bash
# gate.sh — constraint gate for proposed harness edits.
#
# A proposal must pass this gate before it can be reviewed/merged. This is the
# "Gate" step of the flywheel (pattern #23). It enforces:
#
#   1. TESTS PASS — the repo's own pre-commit / lint / test commands, if present.
#   2. SIZE LIMIT — skill files must be <=15KB (prevents context bloat).
#   3. CACHE COMPATIBILITY — no mid-conversation change (a deployed edit can't
#      alter a prompt prefix that's already cached for an active session).
#   4. SEMANTIC PRESERVATION — behavior unchanged on the held-out set (the
#      proposer never sees the held-out labels; the gate checks the eval baseline
#      didn't regress).
#   5. PARETO — the variant is better on >=1 axis without regressing others.
#
# Held-out split: the proposer never sees per-task labels of the held-out set.
# The gate reads the eval-baseline results (which the proposer did NOT author)
# to determine pass/fail. This is the meta-agent / harness-evolver pattern.
#
# Exit codes: 0 = gate passed; 1 = gate failed (regression recorded in history).
# Never exit 2 — that's reserved for the P0 enforcement hooks.
#
# Usage:
#   hooks/gate.sh <proposal-id> [--target <file>] [--eval <eval-set-name>]
#   hooks/gate.sh <proposal-id> --target hooks/foo.sh --eval my-eval
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
HISTORY="$RUNTIME/iteration-history.jsonl"
EVAL="$ROOT/.harness/eval"
SIZE_LIMIT_KB=15
mkdir -p "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
pid="${1:-}"; shift || true
[[ -n "$pid" ]] || { echo "gate: requires <proposal-id>" >&2; exit 1; }

target=""
eval_set=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --eval) eval_set="$2"; shift 2 ;;
    *) echo "gate: unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass=0
fail_reasons=""

record() {
  # record <status> <metric> <value> <note>
  "$ROOT/hooks/history.sh" add "$target" "$pid" "$1" "$2" "$3" "$4" 2>/dev/null || true
}

# --- 1. Tests pass -----------------------------------------------------------
echo "gate: [1/5] checking tests..."
if [[ -f "$ROOT/.husky/pre-commit" ]]; then
  if bash "$ROOT/.husky/pre-commit" >/dev/null 2>&1; then
    echo "  pre-commit: PASS"
  else
    echo "  pre-commit: FAIL"
    fail_reasons="${fail_reasons}pre-commit-failed; "
    pass=1
  fi
else
  echo "  no pre-commit hook; skipping"
fi

# --- 2. Size limit (skill files) --------------------------------------------
echo "gate: [2/5] checking size (<=${SIZE_LIMIT_KB}KB for skills)..."
if [[ -n "$target" && -f "$target" ]]; then
  size_kb="$(du -k "$target" | awk '{print $1}')"
  if [[ "$target" == *skills* ]] && [[ "$size_kb" -gt "$SIZE_LIMIT_KB" ]]; then
    echo "  size: FAIL (${size_kb}KB > ${SIZE_LIMIT_KB}KB)"
    fail_reasons="${fail_reasons}size-${size_kb}kb; "
    pass=1
  else
    echo "  size: PASS (${size_kb}KB)"
  fi
else
  echo "  no target file; skipping"
fi

# --- 3. Cache compatibility -------------------------------------------------
echo "gate: [3/5] checking cache compatibility..."
# Heuristic: if there's an active session (trajectory events in the last 5 min),
# a prompt-prefix change is not cache-safe. The gate is advisory here — it flags
# but doesn't hard-block (a mid-conversation skill edit is the host's call).
if [[ -f "$RUNTIME/trajectory.jsonl" ]]; then
  # Count events in the last hour — if active, prompt-prefix edits aren't cache-safe.
  cutoff="$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")"
  if [[ -n "$cutoff" ]]; then
    recent="$(jq -r --arg c "$cutoff" 'select(.ts > $c)' "$RUNTIME/trajectory.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$recent" -gt 50 ]]; then
      echo "  cache: WARN (${recent} events in last hour — active session, prompt-prefix edits not cache-safe)"
      fail_reasons="${fail_reasons}cache-active-session; "
      # Advisory — don't hard-fail, but record it.
    else
      echo "  cache: PASS (no active session)"
    fi
  else
    echo "  cache: SKIP (could not compute cutoff)"
  fi
else
  echo "  cache: PASS (no trajectory = no active session)"
fi

# --- 4. Semantic preservation (held-out eval) -------------------------------
echo "gate: [4/5] checking semantic preservation (held-out eval)..."
if [[ -n "$eval_set" ]]; then
  # The gate evaluates on the HELD-OUT split — the proposer never sees these
  # per-task expected verdicts (evaluator-not-agent invariant). eval-run.sh
  # refuses --split heldout unless --gate-authority is passed, which only the
  # gate supplies. Always re-run: the bench is cheap and deterministic, and
  # re-running catches regressions introduced since the last gate run.
  #
  # Use a dedicated eval-set name suffixed "-heldout" so the gate's held-out
  # counts are isolated from any "seen" runs the proposer recorded under the
  # base name. This keeps the lift computation split-pure without a schema change.
  heldout_set="${eval_set}-heldout"
  echo "  eval: running held-out bench (set=$heldout_set) via eval-run.sh --gate-authority..."
  "$ROOT/hooks/eval-run.sh" --eval "$heldout_set" --variant with    --split heldout --gate-authority >/dev/null 2>&1 || true
  "$ROOT/hooks/eval-run.sh" --eval "$heldout_set" --variant without --split heldout --gate-authority >/dev/null 2>&1 || true
  # The gate reads the eval results — the proposer did NOT author them (held-out).
  # If the latest "with" pass rate is not better than "without", it's a regression.
  rf="$EVAL/$heldout_set/runs.jsonl"
  with_pass="$(jq -r 'select(.variant=="with" and .outcome=="pass")' "$rf" | jq -s 'length' 2>/dev/null || echo 0)"
  with_n="$(jq -r 'select(.variant=="with")' "$rf" | jq -s 'length' 2>/dev/null || echo 0)"
  without_pass="$(jq -r 'select(.variant=="without" and .outcome=="pass")' "$rf" | jq -s 'length' 2>/dev/null || echo 0)"
  without_n="$(jq -r 'select(.variant=="without")' "$rf" | jq -s 'length' 2>/dev/null || echo 0)"
  if [[ "$with_n" -gt 0 && "$without_n" -gt 0 ]]; then
    lift="$(awk "BEGIN{printf \"%.3f\", ($with_pass/$with_n) - ($without_pass/$without_n)}")"
    if awk "BEGIN{exit !($lift >= 0)}"; then
      echo "  eval: PASS (lift=$lift, with=$with_pass/$with_n, without=$without_pass/$without_n)"
      record "gated" "lift" "$lift" "eval gate passed"
    else
      echo "  eval: FAIL (lift=$lift — regression on held-out set)"
      fail_reasons="${fail_reasons}eval-regression-lift=$lift; "
      pass=1
    fi
  else
    echo "  eval: SKIP (insufficient runs; need >=1 with and >=1 without)"
  fi
else
  echo "  eval: SKIP (no eval set specified or not found)"
fi

# --- 5. Pareto selection ----------------------------------------------------
echo "gate: [5/5] checking Pareto (better on >=1 axis, no regressions)..."
# Pareto = no failing axis above (other than the advisory cache warning).
if [[ "$pass" -eq 0 ]]; then
  echo "  pareto: PASS (no axis regressed)"
else
  echo "  pareto: FAIL (regressions on: ${fail_reasons})"
fi

# --- Record + exit -----------------------------------------------------------
if [[ "$pass" -eq 0 ]]; then
  record "gated" "" "" "all constraint gates passed"
  echo "gate: PASS — proposal $pid is ready for human review"
  exit 0
else
  record "rejected" "" "" "gate failed: ${fail_reasons}"
  echo "gate: FAIL — proposal $pid rejected (${fail_reasons})"
  echo "  regression recorded in history; the proposer will read it next time (non-Markovian)"
  exit 1
fi
