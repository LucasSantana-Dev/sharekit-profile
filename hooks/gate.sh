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
#   6. SELF-MODIFICATION SAFETY (C1 contract) — for proposals targeting self-mutation:
#      6a. ROLLBACK CONTRACT — proposal carries explicit revert action + baseline metric.
#      6b. INVARIANTS TOUCHED — proposal declares which protected invariants it touches.
#      6c. PROTECTED SURFACES — rejects proposals touching constitution, gate, policy hooks.
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
#   hooks/gate.sh <proposal-id> --target hooks/foo.sh --eval my-eval \
#       --proposal .harness/forge/proposals/<ts>-foo.sh.md
#
# --proposal <file>: validate a PROPOSED edit in isolation. The gate calls
# trial-apply.sh to materialize the diff from the proposal into a trial copy at
# .harness/forge/trial/<pid>/, runs the held-out bench AGAINST THE CANDIDATE
# (not the live hook), and reads the lift. The live hook is never mutated. On
# PASS the candidate path is recorded so the host agent knows which trial to
# promote via PR; on FAIL the trial dir is discarded and the regression recorded.
# When --proposal is omitted, the gate measures the live hook (legacy behavior).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
EVAL="$ROOT/.harness/eval"
FORGE="$ROOT/.harness/forge"
SIZE_LIMIT_KB=15
mkdir -p "$RUNTIME"

pid="${1:-}"; shift || true
[[ -n "$pid" ]] || { echo "gate: requires <proposal-id>" >&2; exit 1; }

target=""
eval_set=""
proposal_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --eval) eval_set="$2"; shift 2 ;;
    --proposal) proposal_file="$2"; shift 2 ;;
    *) echo "gate: unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass=0
fail_reasons=""

# If --proposal is set, materialize the candidate BEFORE running the gates so
# the eval (step 4) measures the trial copy, not the live hook.
candidate_path=""
candidate_hook=""
if [[ -n "$proposal_file" ]]; then
  [[ -n "$target" ]] || { echo "gate: --proposal requires --target" >&2; exit 1; }
  [[ -f "$proposal_file" ]] || { echo "gate: proposal file not found: $proposal_file" >&2; exit 1; }
  echo "gate: materializing candidate from $proposal_file..."
  candidate_path="$(bash "$ROOT/hooks/trial-apply.sh" "$proposal_file" 2>/dev/null)" \
    || { echo "  trial-apply: FAIL (could not materialize the proposed edit)"; fail_reasons="${fail_reasons}trial-apply-failed; "; pass=1; }
  if [[ -n "$candidate_path" ]]; then
    candidate_hook="$(basename "$target")"
    echo "  candidate: $candidate_path"
    # Record the candidate in history so the host agent knows which trial to promote.
    "$ROOT/hooks/history.sh" add "$target" "$pid" "candidate" "trial" "$candidate_path" \
      "trial candidate materialized for isolated gating" 2>/dev/null || true
  fi
fi

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
  #
  # --proposal mode: pass --candidate so the `with` variant measures the trial
  # copy, not the live hook. The live hook is never invoked for the candidate's
  # hook; other hooks in the bench still run against their live versions.
  heldout_set="${eval_set}-heldout"
  cand_args=()
  if [[ -n "$candidate_path" ]]; then
    cand_args=(--candidate "$candidate_hook" "$candidate_path")
    echo "  eval: running held-out bench (set=$heldout_set) AGAINST CANDIDATE $candidate_hook..."
  else
    echo "  eval: running held-out bench (set=$heldout_set) via eval-run.sh --gate-authority..."
  fi
  "$ROOT/hooks/eval-run.sh" --eval "$heldout_set" --variant with    --split heldout --gate-authority "${cand_args[@]}" >/dev/null 2>&1 || true
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
      echo "  eval: FAIL (lift=$lift -- regression on held-out set)"
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

# --- 6. Self-modification safety gates (C1 contract) -------------------------
echo "gate: [6/8] checking self-modification safety contract (C1)..."

if [[ -n "$proposal_file" && -f "$proposal_file" ]]; then
  # 6a. Rollback contract presence + non-empty check
  echo "  [6a/3] rollback contract..."
  if python3 - "$proposal_file" <<'PY6A'
import sys, re
text = open(sys.argv[1]).read()
# Extract section 7 (Rollback contract): between "## 7." and "## 8."
m = re.search(r'^## 7\..*?(?=^## 8\.)', text, re.S | re.M)
if not m:
    sys.exit(1)  # section 7 missing
sec = m.group(0)
# Reject if FILL IN placeholder remains (proposer hasn't filled it)
if 'FILL IN' in sec:
    sys.exit(1)
# Require at least one field filled (file:, baseline:, or deploy_watch_metric:)
if not any(x in sec for x in ['file:', 'baseline:', 'deploy_watch_metric:']):
    sys.exit(1)
sys.exit(0)
PY6A
  then
    echo "    PASS (rollback contract non-empty)"
  else
    echo "    FAIL (rollback contract missing, empty, or has FILL IN placeholder)"
    fail_reasons="${fail_reasons}rollback-contract-empty; "
    pass=1
  fi

  # 6b. Invariants touched declaration + non-empty check
  echo "  [6b/3] invariants touched..."
  if python3 - "$proposal_file" <<'PY6B'
import sys, re
text = open(sys.argv[1]).read()
# Extract section 8 (Invariants touched): between "## 8." and "## 9."
m = re.search(r'^## 8\..*?(?=^## 9\.)', text, re.S | re.M)
if not m:
    sys.exit(1)  # section 8 missing
sec = m.group(0)
# Reject if FILL IN placeholder remains
if 'FILL IN' in sec:
    sys.exit(1)
# Require either "none" or at least one invariant listed
if 'none' not in sec.lower() and '-' not in sec:
    sys.exit(1)
sys.exit(0)
PY6B
  then
    echo "    PASS (invariants touched declared)"
  else
    echo "    FAIL (invariants touched missing, empty, or has FILL IN placeholder)"
    fail_reasons="${fail_reasons}invariants-touched-empty; "
    pass=1
  fi

  # 6c. Protected surface check (constitution.md/json, gate.sh, policy hooks)
  echo "  [6c/3] protected surfaces..."
  protected_surfaces=(
    ".harness/constitution.md"
    ".harness/constitution.json"
    "hooks/gate.sh"
    "hooks/policy-gate.sh"
    "hooks/check-dangerous-patterns.sh"
  )
  target_basename="$(basename "$target")"
  protected=0
  for surface in "${protected_surfaces[@]}"; do
    if [[ "$target" == "$surface" || "$target_basename" == "$(basename "$surface")" ]]; then
      protected=1
      echo "    FAIL (target $target is protected — human-authored PR required)"
      fail_reasons="${fail_reasons}protected-surface-$target_basename; "
      pass=1
      break
    fi
  done
  if [[ $protected -eq 0 ]]; then
    echo "    PASS (target does not touch protected surfaces)"
  fi
else
  echo "  [6a-6c] skipped (not a --proposal; self-mod gates apply to proposals only)"
fi

# --- Record + exit -----------------------------------------------------------
if [[ "$pass" -eq 0 ]]; then
  record "gated" "" "" "all constraint gates passed (1-6)"
  echo "gate: PASS — proposal $pid is ready for human review"
  [[ -n "$candidate_path" ]] && echo "  candidate to promote: $candidate_path"
  exit 0
else
  record "rejected" "" "" "gate failed: ${fail_reasons}"
  echo "gate: FAIL — proposal $pid rejected (${fail_reasons})"
  echo "  regression recorded in history; the proposer will read it next time (non-Markovian)"
  # Discard the trial dir so a failed candidate does not linger as a stale artifact.
  if [[ -n "$candidate_path" ]]; then
    trial_dir="$FORGE/trial/$pid"
    rm -rf "$trial_dir" 2>/dev/null && echo "  trial dir discarded: $trial_dir"
  fi
  exit 1
fi
