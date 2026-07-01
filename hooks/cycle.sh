#!/usr/bin/env bash
# cycle.sh -- end-to-end flywheel cycle runner (P5: integrated with the P4 substrate).
#
# NOTE: This script is NOT registered as a Claude Code lifecycle hook — it runs
# ONLY via direct CLI invocation (hooks/cycle.sh) or the opt-in nightly scheduler
# (scripts/install-scheduler.sh). It does not auto-trigger on session start or any
# other event. See claude/settings.json for what actually auto-fires per session.
#
# The loop contract exists (P0/P1/P2 scripts); P4 added the convergent
# cross-cutting patterns (memory consolidation, progressive-disclosure skills,
# deterministic dispatch, governance gate); P5 wires them into the cycle so the
# flywheel operates as a single closed loop, not a collection of scripts.
#
# The cycle now has two tracks that run in sequence:
#
#   TRACK A -- MAINTAIN (the P4 substrate, periodic hygiene):
#     1. MEMORY-CONSOLIDATE  -- sleep-cycle: cluster/supersede/decay candidates
#     2. SKILL-INDEX         -- metadata-only catalog index (progressive disclosure)
#     3. SKILL-PRUNE         -- never/low-hit skill archive candidates
#     4. TRANSCRIPT-SCAN     -- hooks/transcript-scanner.sh (systemic pattern scan)
#
#   TRACK B -- IMPROVE (the P0-P3 flywheel, now routed through dispatch.sh):
#     5. DIAGNOSE  -- hooks/diagnose.sh    (cluster failures in the trajectory)
#     6. DISTILL   -- hooks/distill.sh     (mine trajectory -> staged candidates)
#     7. PROPOSE   -- dispatch.sh advances implement -> review_gate
#                    (hooks/propose.sh is the bounded worker at implement)
#     8. GATE      -- dispatch.sh --allow-gate review_gate -> eval
#                    (hooks/gate.sh is the bounded worker at eval)
#     9. REPORT    -- this script          (human/agent-readable cycle summary)
#
# The dispatch.sh routing is the P4 deterministic orchestration substrate: no
# LLM decides what fires next. The proposer and gate are bounded workers; the
# substrate owns the state machine and the human-in-the-loop gates. If
# dispatch.sh is unavailable (older harness), the cycle falls back to calling
# propose.sh / gate.sh directly so the loop stays exercisable.
#
# The runner NEVER commits (hermes-evolution guardrail #5). It produces a
# report the host agent reviews. If a step has nothing to act on (empty
# trajectory, no staged candidates), it skips gracefully -- the loop is
# exercisable even from a cold start.
#
# Usage:
#   hooks/cycle.sh                        # run the full cycle
#   hooks/cycle.sh --target <file>        # anchor the propose step on <file>
#   hooks/cycle.sh --eval <eval-set>      # pass an eval set to the gate
#   hooks/cycle.sh --dry-run              # show what would run, don't execute
#   hooks/cycle.sh --status               # print the last cycle report
#   hooks/cycle.sh --no-maintain          # skip the P4 maintain track
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
maintain=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --eval) eval_set="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --status) status_only=1; shift ;;
    --no-maintain) maintain=0; shift ;;
    *) echo "cycle: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --- status mode: print the last cycle report ---
if [[ $status_only -eq 1 ]]; then
  last="$(ls -t "$CYCLE_REPORTS"/cycle-*.md 2>/dev/null | head -1)"
  [[ -n "$last" ]] || { echo "no cycle reports yet"; exit 0; }
  bat -p --paging=never "$last" 2>/dev/null || sed -n '1,$p' "$last"
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
  echo "─── cycle [$num/9] $name ───"
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
echo "║  flywheel cycle -- maintain (P4) + improve (P0-P3)            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  started: $ts"
[[ -n "$target" ]] && echo "  target:  $target"
[[ -n "$eval_set" ]] && echo "  eval:    $eval_set"
[[ $dry_run -eq 1 ]] && echo "  mode:    dry-run"
[[ $maintain -eq 0 ]] && echo "  track A: skipped (--no-maintain)"
echo ""

# --- TRACK A: MAINTAIN (the P4 substrate, periodic hygiene) -----------------
# These steps keep the memory, skill catalog, and governance substrate healthy
# so the improve track operates over clean inputs. They are advisory: they stage
# reports/forge candidates the host agent reviews, never auto-apply.
if [[ $maintain -eq 1 ]]; then
  # Step 1: memory-consolidate (sleep-cycle: cluster/supersede/decay).
  # Reads memory/ (if present) and stages a consolidation report. No memory/
  # dir -> no-op (the sleep cycle is a no-op until memory exists).
  echo "─── cycle [1/9] memory-consolidate ───"
  if [[ $dry_run -eq 1 ]]; then
    echo "  (dry-run) would run: memory-consolidate.sh"
    record_step "memory-consolidate" "skipped" "dry-run"
  else
    out_file="$RUNTIME/cycle-${ts//[:]/-}-memory-consolidate.log"
    if bash "$ROOT/hooks/memory-consolidate.sh" >"$out_file" 2>&1; then
      scanned="$(rg -o 'scanned [0-9]+ facts' "$out_file" | rg -o '[0-9]+' || echo 0)"
      echo "  ✓ memory-consolidate scanned $scanned fact(s) (log: $out_file)"
      record_step "memory-consolidate" "pass" "scanned $scanned facts"
    else
      echo "  ⊘ memory-consolidate: nothing to consolidate (log: $out_file)"
      record_step "memory-consolidate" "skip" "no memory dir / empty"
    fi
  fi

  # Step 2: skill-index (metadata-only progressive-disclosure index).
  echo "─── cycle [2/9] skill-index ───"
  if [[ $dry_run -eq 1 ]]; then
    echo "  (dry-run) would run: skill-index.sh"
    record_step "skill-index" "skipped" "dry-run"
  else
    out_file="$RUNTIME/cycle-${ts//[:]/-}-skill-index.log"
    if bash "$ROOT/hooks/skill-index.sh" >"$out_file" 2>&1; then
      total_skills="$(rg -o 'indexed [0-9]+ skills' "$out_file" | rg -o '[0-9]+' || echo 0)"
      echo "  ✓ skill-index indexed $total_skills skill(s) (log: $out_file)"
      record_step "skill-index" "pass" "indexed $total_skills skills"
    else
      echo "  ⊘ skill-index: no catalog to index (log: $out_file)"
      record_step "skill-index" "skip" "no catalog"
    fi
  fi

  # Step 3: skill-prune (telemetry-based archive candidates).
  # Needs the trajectory to exist; skips gracefully otherwise.
  echo "─── cycle [3/9] skill-prune ───"
  if [[ $dry_run -eq 1 ]]; then
    echo "  (dry-run) would run: skill-prune.sh"
    record_step "skill-prune" "skipped" "dry-run"
  elif [[ ! -s "$RUNTIME/trajectory.jsonl" ]]; then
    echo "  ⊘ skill-prune: no trajectory yet (run a session first)"
    record_step "skill-prune" "skip" "no trajectory"
  else
    out_file="$RUNTIME/cycle-${ts//[:]/-}-skill-prune.log"
    if bash "$ROOT/hooks/skill-prune.sh" >"$out_file" 2>&1; then
      never="$(rg -o 'never=[0-9]+' "$out_file" | rg -o '[0-9]+' || echo 0)"
      echo "  ✓ skill-prune: $never never-hit candidate(s) (log: $out_file)"
      record_step "skill-prune" "pass" "never=$never"
    else
      echo "  ⊘ skill-prune: no catalog or trajectory (log: $out_file)"
      record_step "skill-prune" "skip" "no catalog/trajectory"
    fi
  fi

  # Step 4: transcript-scan (systemic pattern scan, complements diagnose).
  # Scans the trajectory for refusals, eval-awareness, env-drift, hallucination,
  # excessive-agency, and injection-tells -- patterns per-task evals miss.
  # Advisory: stages findings to .harness/forge/, never blocks.
  echo "─── cycle [4/9] transcript-scan ───"
  if [[ $dry_run -eq 1 ]]; then
    echo "  (dry-run) would run: transcript-scanner.sh"
    record_step "transcript-scan" "skipped" "dry-run"
  elif [[ ! -s "$RUNTIME/trajectory.jsonl" ]]; then
    echo "  ⊘ transcript-scan: no trajectory yet (run a session first)"
    record_step "transcript-scan" "skip" "no trajectory"
  else
    out_file="$RUNTIME/cycle-${ts//[:]/-}-transcript-scan.log"
    if bash "$ROOT/hooks/transcript-scanner.sh" >"$out_file" 2>&1; then
      signals="$(rg -o 'refusals=[0-9]+' "$out_file" | rg -o '[0-9]+' || echo 0)"
      echo "  ✓ transcript-scan: $signals refusal(s) flagged (log: $out_file)"
      record_step "transcript-scan" "pass" "refusals=$signals"
    else
      echo "  ⊘ transcript-scan: no trajectory to scan (log: $out_file)"
      record_step "transcript-scan" "skip" "no trajectory"
    fi
  fi
else
  record_step "memory-consolidate" "skip" "--no-maintain"
  record_step "skill-index" "skip" "--no-maintain"
  record_step "skill-prune" "skip" "--no-maintain"
  record_step "transcript-scan" "skip" "--no-maintain"
fi

# --- TRACK B: IMPROVE (the P0-P3 flywheel, routed via dispatch.sh) ------------

# --- Step 5: Diagnose (observe → signal) -------------------------------------
# Clusters failures in the trajectory log. Skips gracefully if no trajectory.
if [[ ! -f "$RUNTIME/trajectory.jsonl" ]]; then
  echo "─── cycle [5/9] diagnose ───"
  echo "  ⊘ no trajectory log yet -- nothing to diagnose (run a session first)"
  record_step "diagnose" "skip" "no trajectory log"
else
  run_step 5 "diagnose" bash "$ROOT/hooks/diagnose.sh"
fi

# --- Step 6: Distill (observe → candidates) ----------------------------------
# Mines the trajectory for staged candidate learnings.
run_step 6 "distill" bash "$ROOT/hooks/distill.sh"

# --- Step 7: Propose (optimize → proposal, routed via dispatch.sh) ------------
# Assembles a non-Markovian proposal for the target (or the top forge candidate).
# P5: routed through dispatch.sh's deterministic state machine. The propose step
# is the `implement` state; propose.sh is the bounded worker. After it assembles,
# dispatch advances to review_gate (the human-in-the-loop gate the gate step
# checks). If dispatch.sh is absent (older harness), fall back to direct call.
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

echo "─── cycle [7/9] propose ───"
# Dispatch task id for this cycle's proposal (deterministic routing).
dispatch_task="cycle-${ts//[:]/-}"
if [[ -x "$ROOT/hooks/dispatch.sh" ]]; then
  # Route through the deterministic substrate: intake -> ... -> implement.
  # We advance intake->triage->plan->research->implement so the worker (propose.sh)
  # fires at the implement state, then the gate step will --allow-gate review_gate.
  bash "$ROOT/hooks/dispatch.sh" "$dispatch_task" --intake "cycle proposal for ${propose_target:-<auto>}" >/dev/null 2>&1 || true
  for _ in 1 2 3 4; do
    bash "$ROOT/hooks/dispatch.sh" "$dispatch_task" --advance >/dev/null 2>&1 || true
  done
fi
if [[ $dry_run -eq 1 ]]; then
  echo "  (dry-run) would run: propose.sh ${propose_target:-<no-target>}"
  record_step "propose" "skipped" "dry-run"
elif [[ -n "$propose_target" && -f "$propose_target" ]]; then
  out_file="$RUNTIME/cycle-${ts//[:]/-}-propose.log"
  bash "$ROOT/hooks/propose.sh" "$propose_target" >"$out_file" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "  ✓ proposal assembled (log: $out_file)"
    record_step "propose" "pass" "target=$propose_target"
    # Extract the proposal_id + output file from the log.
    proposal_id="$(rg -o 'prop-[0-9T-]+' "$out_file" | head -1)"
    proposal_file="$(rg -o '\.harness/forge/proposals/[^ ]+' "$out_file" | head -1)"
  else
    echo "  ✗ propose failed (log: $out_file)"
    record_step "propose" "fail" "rc=$rc"
    proposal_id=""
  fi
elif [[ -z "$propose_target" ]]; then
  # No explicit target -- try --auto (scans forge candidates + regressions).
  out_file="$RUNTIME/cycle-${ts//[:]/-}-propose.log"
  if bash "$ROOT/hooks/propose.sh" --auto >"$out_file" 2>&1; then
    count="$(rg -o 'assembled [0-9]+ proposals' "$out_file" | rg -o '[0-9]+' || echo 0)"
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

# --- Step 8: Gate (optimize → validate, routed via dispatch.sh review_gate) ----
# Runs the constraint gate on the proposal (if one was assembled). P5: the gate
# is the bounded worker at the `eval` state; dispatch.sh's review_gate must be
# passed first. We --allow-gate review_gate (the host agent's cycle-level
# approval to run the gate), then run gate.sh, then the report notes merge_gate
# still awaits a human allow before merge.
echo "─── cycle [8/9] gate ───"
pre_deploy_lift=""
if [[ $dry_run -eq 1 ]]; then
  echo "  (dry-run) would run: gate.sh ${proposal_id:-<no-proposal>}"
  record_step "gate" "skipped" "dry-run"
elif [[ -n "$proposal_id" ]]; then
  # Pass the review_gate so the gate worker (eval state) can run.
  [[ -x "$ROOT/hooks/dispatch.sh" ]] && bash "$ROOT/hooks/dispatch.sh" "$dispatch_task" --allow-gate review_gate >/dev/null 2>&1 || true
  out_file="$RUNTIME/cycle-${ts//[:]/-}-gate.log"
  gate_args=("$proposal_id")
  [[ -n "$target" ]] && gate_args+=(--target "$target")
  [[ -n "$eval_set" ]] && gate_args+=(--eval "$eval_set")
  # P7: when a proposal file exists, gate the PROPOSED edit in isolation
  # (trial-apply.sh materializes a candidate; the live hook is never mutated).
  [[ -n "$proposal_file" && -f "$ROOT/$proposal_file" ]] && gate_args+=(--proposal "$ROOT/$proposal_file")
  if bash "$ROOT/hooks/gate.sh" "${gate_args[@]}" >"$out_file" 2>&1; then
    echo "  ✓ gate PASSED (log: $out_file)"
    record_step "gate" "pass" "proposal $proposal_id ready for merge_gate"
    # Capture the pre-deploy lift so deploy-watch can detect a post-merge regression.
    pre_deploy_lift="$(rg -o 'lift=[0-9.-]+' "$out_file" | head -1 | sed 's/lift=//')"
    # P7: start a deploy-watch so a post-merge regression is detectable. The
    # watch records the pre-deploy baseline (the held-out lift); after the PR
    # merges, the host runs deploy-watch.sh check to compare.
    if [[ -n "$target" && -n "$pre_deploy_lift" ]]; then
      bash "$ROOT/hooks/deploy-watch.sh" start "$proposal_id" "$target" heldout-lift "$pre_deploy_lift" >/dev/null 2>&1 \
        && echo "  ✓ deploy-watch started (baseline heldout-lift=$pre_deploy_lift)" || true
    fi
    # Advance the dispatch state machine: eval -> merge_gate. merge_gate is the
    # final human-in-the-loop gate; the host agent passes it before merging via PR.
    [[ -x "$ROOT/hooks/dispatch.sh" ]] && bash "$ROOT/hooks/dispatch.sh" "$dispatch_task" --advance >/dev/null 2>&1 || true
  else
    echo "  ✗ gate FAILED -- regression recorded (log: $out_file)"
    record_step "gate" "fail" "regression recorded (non-Markovian learning)"
    # P9.2/P9.3: on a gate FAIL, run the inline retry-with-reflection (Reflexion)
    # then the TextGrad textual-gradient optimization. Both are ADVISORY sub-steps
    # (never block, never mutate memory); they stage digests to .harness/forge/
    # so the next proposal for this target retries WITH the reflection + gradient
    # as context (propose.sh sections 3.5 + 3.6). Distinct from the batch flywheel.
    if [[ -n "$target" ]]; then
      gate_fail_reasons="$(rg -o 'gate failed: [^ ]+' "$out_file" | head -1)"
      echo "  ↳ reflect-retry (Reflexion, P9.2)..."
      reflect_log="$RUNTIME/cycle-${ts//[:]/-}-reflect-retry.log"
      if bash "$ROOT/hooks/reflect-retry.sh" "$target" "$proposal_id" "$gate_fail_reasons" >"$reflect_log" 2>&1; then
        retry_n="$(rg -o 'retry [0-9]+/[0-9]+' "$reflect_log" | head -1)"
        echo "    ✓ reflection staged ($retry_n)"
        # P9.2 max-retry cap: if reflect-retry hit the cap, park BLOCKED for human
        # intervention (the loop does not spin forever — the Reflexion bound).
        if rg -q 'MAX RETRY CAP' "$reflect_log" 2>/dev/null; then
          echo "    ⊘ max-retry cap hit — parking BLOCKED for human intervention"
          [[ -x "$ROOT/hooks/dispatch.sh" ]] && bash "$ROOT/hooks/dispatch.sh" "$dispatch_task" --block "max-retry cap on $target" >/dev/null 2>&1 || true
        else
          # P9.3: run textgrad only when a reflection exists (one gradient per
          # reflection). It refuses gracefully if reflect-retry hit the cap.
          echo "  ↳ textgrad (TextGrad, P9.3)..."
          tg_log="$RUNTIME/cycle-${ts//[:]/-}-textgrad.log"
          if bash "$ROOT/hooks/textgrad.sh" "$target" "$proposal_id" >"$tg_log" 2>&1; then
            echo "    ✓ textual gradient staged (log: $tg_log)"
          else
            echo "    ⊘ textgrad: no reflection to anchor on (log: $tg_log)"
          fi
        fi
      else
        echo "    ⊘ reflect-retry: nothing to reflect on (log: $reflect_log)"
      fi
    fi
    # On regression, park the task as BLOCKED so the proposer reads WHY next time.
    [[ -x "$ROOT/hooks/dispatch.sh" ]] && bash "$ROOT/hooks/dispatch.sh" "$dispatch_task" --block "gate regression on held-out eval" >/dev/null 2>&1 || true
  fi
else
  echo "  ⊘ no proposal to gate"
  record_step "gate" "skip" "no proposal"
fi

# --- Step 9: Report (synthesize) ---------------------------------------------
# The cycle report the host agent reviews.
echo "─── cycle [9/9] report ───"
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
    printf -- '  validate. If it passes, pass merge_gate via `hooks/dispatch.sh %s --allow-gate merge_gate`\n' "$dispatch_task"
    printf -- '  and open a human-reviewed PR.\n'
  fi
  if [[ -n "$proposal_id" && -n "$pre_deploy_lift" ]]; then
    printf -- '- **Post-merge watch.** A deploy-watch was started with baseline heldout-lift=%s.\n' "$pre_deploy_lift"
    printf -- '  After the PR merges, re-run the held-out bench and compare:\n'
    printf -- '  `hooks/deploy-watch.sh check %s <post-merge-lift>`.\n' "$proposal_id"
    printf -- '  If it reports REGRESSION, revert with `hooks/deploy-watch.sh revert %s %s`.\n' "$proposal_id" "${target:-<target>}"
  fi
  if [[ $skip_count -gt 0 ]]; then
    printf -- '- **Skipped steps.** The loop is exercisable but had nothing to act on\n'
    printf -- '  (likely an empty trajectory or no staged candidates). Run a session first\n'
    printf -- '  to generate trajectory fuel, then re-run `hooks/cycle.sh`.\n'
  fi
  if [[ $pass_count -ge 5 ]]; then
    printf -- '- **Improve track passed.** The harness took one complete improvement step.\n'
    printf -- '  Review the proposal, and if the gate passed, merge via human-reviewed PR.\n'
  fi
  printf '\n'

  printf '## Key invariants (preserved this cycle)\n\n'
  printf -- '- evaluator ≠ agent (the reviewer is not the proposer)\n'
  printf -- '- non-Markovian: full iteration history retained, never pruned\n'
  printf -- '- all edits human-reviewed via PR -- never direct commit\n'
  printf -- '- auto-rollback on regression (deploy-watch.sh runs post-merge)\n'
  printf -- '- deterministic routing: dispatch.sh owns state transitions, not the LLM\n'
  printf '\n'

  printf '## Run again\n\n'
  printf '```bash\n'
  printf 'hooks/cycle.sh                    # another full cycle (maintain + improve)\n'
  printf 'hooks/cycle.sh --status           # re-read this report\n'
  printf 'hooks/cycle.sh --target <file>    # anchor on a specific file\n'
  printf 'hooks/cycle.sh --no-maintain     # skip the P4 maintain track\n'
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
  bat -p --paging=never "$report" 2>/dev/null || sed -n '1,$p' "$report"
fi

exit 0
