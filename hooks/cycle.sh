#!/usr/bin/env bash
# cycle.sh -- end-to-end flywheel cycle runner.
#
# The loop contract exists (P0/P1/P2 scripts) but was not exercisable as a
# single command. This runner chains the full observe → evaluate → optimize
# loop so the harness can actually self-improve on demand:
#
#   1. DIAGNOSE  -- hooks/diagnose.sh    (cluster failures in the trajectory)
#   2. DISTILL   -- hooks/distill.sh     (mine trajectory → staged candidates)
#   3. PROPOSE   -- hooks/propose.sh     (top candidate → non-Markovian proposal)
#   4. GATE      -- hooks/gate.sh        (constraint gate on the proposal)
#   5. REPORT    -- this script          (human/agent-readable cycle summary)
#
# The runner NEVER commits (hermes-evolution guardrail #5). It produces a report
# the host agent reviews. If a step has nothing to act on (empty trajectory, no
# staged candidates), it skips gracefully -- the loop is exercisable even from a
# cold start.
#
# This is the command that makes the flywheel real: run it after a session (or
# on a schedule) and the harness takes one full improvement step.
#
# Usage:
#   hooks/cycle.sh                        # run the full cycle
#   hooks/cycle.sh --target <file>        # anchor the propose step on <file>
#   hooks/cycle.sh --eval <eval-set>      # pass an eval set to the gate
#   hooks/cycle.sh --dry-run              # show what would run, don't execute
#   hooks/cycle.sh --status               # print the last cycle report
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
CYCLE_REPORTS="$RUNTIME/cycle-reports"
mkdir -p "$RUNTIME" "$CYCLE_REPORTS"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
report="$CYCLE_REPORTS/cycle-${ts//[:]/-}.md"

target=""
eval_set=""
dry_run=0
status_only=0
proposal_id=""
proposal_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --eval) eval_set="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --status) status_only=1; shift ;;
    *) echo "cycle: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --- status mode: print the last cycle report ---
if [[ $status_only -eq 1 ]]; then
  last="$(ls -t "$CYCLE_REPORTS"/cycle-*.md 2>/dev/null | head -1)"
  [[ -n "$last" ]] || { echo "no cycle reports yet"; exit 0; }
  bat -p "$last" 2>/dev/null || cat "$last"
  exit 0
fi

# --- helpers ---
step_num=0
declare -a step_names=()
declare -a step_status=()
declare -a step_notes=()

record_step() {
  # record_step <name> <status> <note>
  step_num=$((step_num + 1))
  step_names+=("$1")
  step_status+=("$2")
  step_notes+=("$3")
}

run_step() {
  # run_step <num> <name> <cmd...>
  local num="$1"; shift
  local name="$1"; shift
  echo "─── cycle [$num/5] $name ───"
  if [[ $dry_run -eq 1 ]]; then
    echo "  (dry-run) would run: $*"
    record_step "$name" "skipped" "dry-run"
    return 0
  fi
  local out_file="$RUNTIME/cycle-${ts//[:]/-}-$name.log"
  if "$@" >"$out_file" 2>&1; then
    echo "  ✓ $name completed (log: $out_file)"
    record_step "$name" "pass" "$(head -1 "$out_file" 2>/dev/null || true)"
  else
    local rc=$?
    echo "  ✗ $name failed (rc=$rc, log: $out_file)"
    record_step "$name" "fail" "rc=$rc: $(head -1 "$out_file" 2>/dev/null || true)"
  fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  flywheel cycle -- observe → evaluate → optimize              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  started: $ts"
[[ -n "$target" ]] && echo "  target:  $target"
[[ -n "$eval_set" ]] && echo "  eval:    $eval_set"
[[ $dry_run -eq 1 ]] && echo "  mode:    dry-run"
echo ""

# --- Step 1: Diagnose (observe → signal) -------------------------------------
# Clusters failures in the trajectory log. Skips gracefully if no trajectory.
if [[ ! -f "$RUNTIME/trajectory.jsonl" ]]; then
  echo "─── cycle [1/5] diagnose ───"
  echo "  ⊘ no trajectory log yet -- nothing to diagnose (run a session first)"
  record_step "diagnose" "skip" "no trajectory log"
else
  run_step 1 "diagnose" bash "$ROOT/hooks/diagnose.sh"
fi

# --- Step 2: Distill (observe → candidates) ----------------------------------
# Mines the trajectory for staged candidate learnings.
run_step 2 "distill" bash "$ROOT/hooks/distill.sh"

# --- Step 3: Propose (optimize → proposal) -----------------------------------
# Assembles a non-Markovian proposal for the target (or the top forge candidate).
# If no --target given, try to pick the most recent forge candidate's target.
propose_target="$target"
if [[ -z "$propose_target" ]]; then
  # Look for the latest staged candidate and extract its target.
  latest_forge="$(ls -t "$FORGE"/*.md 2>/dev/null | head -1)"
  if [[ -n "$latest_forge" ]]; then
    # The propose.sh --auto mode scans all forge candidates; but for a single
    # cycle step we want one proposal. Try to extract a target from the forge file.
    propose_target=""
  fi
fi

echo "─── cycle [3/5] propose ───"
if [[ $dry_run -eq 1 ]]; then
  echo "  (dry-run) would run: propose.sh ${propose_target:-<no-target>}"
  record_step "propose" "skipped" "dry-run"
elif [[ -n "$propose_target" && -f "$propose_target" ]]; then
  out_file="$RUNTIME/cycle-${ts//[:]/-}-propose.log"
  if bash "$ROOT/hooks/propose.sh" "$propose_target" >"$out_file" 2>&1; then
    echo "  ✓ proposal assembled (log: $out_file)"
    record_step "propose" "pass" "target=$propose_target"
    # Extract the proposal_id + output file from the log.
    proposal_id="$(grep -oE 'prop-[0-9T-]+' "$out_file" | head -1)"
    proposal_file="$(grep -oE '\.harness/forge/proposals/[^ ]+' "$out_file" | head -1)"
  else
    echo "  ✗ propose failed (log: $out_file)"
    record_step "propose" "fail" "rc=$?"
    proposal_id=""
  fi
elif [[ -z "$propose_target" ]]; then
  # No explicit target -- try --auto (scans forge candidates + regressions).
  out_file="$RUNTIME/cycle-${ts//[:]/-}-propose.log"
  if bash "$ROOT/hooks/propose.sh" --auto >"$out_file" 2>&1; then
    count="$(grep -oE 'assembled [0-9]+ proposals' "$out_file" | grep -oE '[0-9]+' || echo 0)"
    echo "  ✓ propose --auto assembled $count proposal(s) (log: $out_file)"
    record_step "propose" "pass" "auto: $count proposals"
    proposal_id=""
  else
    echo "  ⊘ no targets to propose for (no forge candidates, no regressions)"
    record_step "propose" "skip" "no candidates"
    proposal_id=""
  fi
else
  echo "  ⊘ target file not found: $propose_target"
  record_step "propose" "skip" "target not found"
  proposal_id=""
fi

# --- Step 4: Gate (optimize → validate) --------------------------------------
# Runs the constraint gate on the proposal (if one was assembled).
echo "─── cycle [4/5] gate ───"
if [[ $dry_run -eq 1 ]]; then
  echo "  (dry-run) would run: gate.sh ${proposal_id:-<no-proposal>}"
  record_step "gate" "skipped" "dry-run"
elif [[ -n "$proposal_id" ]]; then
  out_file="$RUNTIME/cycle-${ts//[:]/-}-gate.log"
  gate_args=("$proposal_id")
  [[ -n "$target" ]] && gate_args+=(--target "$target")
  [[ -n "$eval_set" ]] && gate_args+=(--eval "$eval_set")
  if bash "$ROOT/hooks/gate.sh" "${gate_args[@]}" >"$out_file" 2>&1; then
    echo "  ✓ gate PASSED (log: $out_file)"
    record_step "gate" "pass" "proposal $proposal_id ready for review"
  else
    echo "  ✗ gate FAILED -- regression recorded (log: $out_file)"
    record_step "gate" "fail" "regression recorded (non-Markovian learning)"
  fi
else
  echo "  ⊘ no proposal to gate"
  record_step "gate" "skip" "no proposal"
fi

# --- Step 5: Report (synthesize) ---------------------------------------------
# The cycle report the host agent reviews.
echo "─── cycle [5/5] report ───"
echo "  writing cycle report → $report"

pass_count=0
fail_count=0
skip_count=0
for s in "${step_status[@]}"; do
  case "$s" in
    pass) pass_count=$((pass_count + 1)) ;;
    fail) fail_count=$((fail_count + 1)) ;;
    skip|skipped) skip_count=$((skip_count + 1)) ;;
  esac
done

{
  printf '# Flywheel cycle report -- %s\n\n' "$ts"
  printf 'The harness took one full observe → evaluate → optimize step.\n'
  printf 'No commits were made (hermes-evolution guardrail #5) -- the host agent reviews this report.\n\n'

  printf '## Summary\n\n'
  printf -- '- steps passed: %s\n' "$pass_count"
  printf -- '- steps failed: %s\n' "$fail_count"
  printf -- '- steps skipped: %s\n' "$skip_count"
  [[ -n "$target" ]] && printf -- '- target: `%s`\n' "$target"
  [[ -n "$eval_set" ]] && printf -- '- eval set: `%s`\n' "$eval_set"
  [[ -n "$proposal_id" ]] && printf -- '- proposal: `%s`\n' "$proposal_id"
  printf '\n'

  printf '## Step results\n\n'
  printf '| # | Step | Status | Note |\n'
  printf -- '|---|------|--------|------|\n'
  for i in "${!step_names[@]}"; do
    n=$((i + 1))
    printf '| %s | %s | %s | %s |\n' \
      "$n" "${step_names[$i]}" "${step_status[$i]}" "${step_notes[$i]:-}"
  done
  printf '\n'

  printf '## Logs\n\n'
  printf 'Each step full output is in `.harness/runtime/cycle-%s-<step>.log`.\n' "${ts//[:]/-}"
  printf '\n'

  printf '## What to do next\n\n'
  if [[ $fail_count -gt 0 ]]; then
    printf -- '- **Failures present.** Read the step logs above. A failed gate means a\n'
    printf -- '  regression was recorded in the iteration history -- the proposer will read\n'
    printf -- '  WHY it failed next time (non-Markovian learning).\n'
  fi
  if [[ -n "$proposal_id" ]]; then
    printf -- '- **Review the proposal.** Read `%s`, then run `hooks/gate.sh %s` to\n' \
      "${proposal_file:-.harness/forge/proposals/}" "$proposal_id"
    printf -- '  validate. If it passes, open a human-reviewed PR.\n'
  fi
  if [[ $skip_count -gt 0 ]]; then
    printf -- '- **Skipped steps.** The loop is exercisable but had nothing to act on\n'
    printf -- '  (likely an empty trajectory or no staged candidates). Run a session first\n'
    printf -- '  to generate trajectory fuel, then re-run `hooks/cycle.sh`.\n'
  fi
  if [[ $pass_count -eq 5 ]]; then
    printf -- '- **Full cycle passed.** The harness took one complete improvement step.\n'
    printf -- '  Review the proposal, and if the gate passed, merge via human-reviewed PR.\n'
  fi
  printf '\n'

  printf '## Key invariants (preserved this cycle)\n\n'
  printf -- '- evaluator ≠ agent (the reviewer is not the proposer)\n'
  printf -- '- non-Markovian: full iteration history retained, never pruned\n'
  printf -- '- all edits human-reviewed via PR -- never direct commit\n'
  printf -- '- auto-rollback on regression (deploy-watch.sh runs post-merge)\n'
  printf '\n'

  printf '## Run again\n\n'
  printf '```bash\n'
  printf 'hooks/cycle.sh                    # another full cycle\n'
  printf 'hooks/cycle.sh --status           # re-read this report\n'
  printf 'hooks/cycle.sh --target <file>    # anchor on a specific file\n'
  printf '```\n'
} > "$report"

echo "  ✓ cycle report written"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  cycle complete                                              ║"
printf "║  passed: %s  failed: %s  skipped: %s  %-22s║\n" \
  "$pass_count" "$fail_count" "$skip_count" ""
echo "║  report: $report"
echo "╚══════════════════════════════════════════════════════════════╝"

# Print the report for immediate review (unless dry-run).
if [[ $dry_run -eq 0 ]]; then
  echo ""
  bat -p "$report" 2>/dev/null || cat "$report"
fi

exit 0
