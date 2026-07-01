#!/usr/bin/env bash
# propose.sh — local evolutionary proposer (the "optimize" half).
#
# This is the engine that actually makes the harness self-improve. It reads the
# FULL non-Markovian iteration history + the latest self-diagnosis + the staged
# distill candidates, assembles a context-rich proposal prompt, and emits it for
# a host-agent reviewer (evaluator ≠ agent) to act on. It NEVER commits directly
# (hermes-evolution guardrail #5) — every proposal goes through human-reviewed PR.
#
# Non-Markovian: the proposer reads prior candidates + WHY they failed before
# writing the next one. This is the meta-harness #1 result — it beats best-of-N
# and model hopping. So this script's job is to assemble that history and hand it
# to the proposing model, not to generate the edit blind.
#
# Contract copied from meta-agent / harness-evolver / hermes-evolution — NOT a
# dependency. No DSPy/GEPA/LangSmith. Local, zero-dep.
#
# Usage:
#   hooks/propose.sh <target>              # assemble proposal context for <target>
#   hooks/propose.sh <target> --from <candidate-id>  # anchor on a distill candidate
#   hooks/propose.sh --auto                # scan forge/ + regressions, propose for each
#
# Output: .harness/forge/proposals/<ts>-<target>.md — a proposal file containing:
#   - the target file's current content
#   - the full iteration history for that target (the "why")
#   - the latest diagnosis clusters relevant to the target
#   - the staged distill candidates
#   - a predicted-impact field + rationale (filled by the proposing model)
#   - a constraint-gate checklist (tests, size, cache, semantic preservation)
#
# The host agent reads this file, fills in the proposed edit + rationale, then
# runs hooks/gate.sh to validate before reviewing via PR.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
PROPOSALS="$FORGE/proposals"
HISTORY="$RUNTIME/iteration-history.jsonl"
mkdir -p "$PROPOSALS" "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

auto=0
target=""
candidate=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) auto=1; shift ;;
    --from) candidate="$2"; shift 2 ;;
    *) target="$1"; shift ;;
  esac
done

die() { echo "propose: $*" >&2; exit 2; }

# --- --auto: scan forge candidates + regressions, propose for each target ---
if [[ $auto -eq 1 ]]; then
  [[ -d "$FORGE" ]] || { echo "propose: no forge/ candidates to propose from"; exit 0; }
  targets=""
  # Targets from staged distill candidates
  while IFS= read -r f; do
    t="$(jq -r '.target // .source_file // empty' "$f" 2>/dev/null)"
    [[ -n "$t" ]] && targets="$targets"$'\n'"$t"
  done < <(fd -e md . "$FORGE" --max-depth 1 2>/dev/null || true)
  # Targets from regressions in history
  if [[ -f "$HISTORY" ]]; then
    while IFS= read -r t; do
      [[ -n "$t" ]] && targets="$targets"$'\n'"$t"
    done < <(jq -r 'select(.status=="regressed") | .target' "$HISTORY" 2>/dev/null)
  fi
  count=0
  for t in $(printf '%s\n' "$targets" | sort -u); do
    [[ -n "$t" ]] || continue
    "$0" "$t" && count=$((count + 1))
  done
  echo "propose --auto: assembled $count proposals"
  exit 0
fi

[[ -n "$target" ]] || die "usage: propose.sh <target> | --auto"
[[ -f "$target" ]] || die "target file not found: $target (run from repo root)"

proposal_id="prop-${ts//[:]/-}"
out="$PROPOSALS/${ts//[:]/-}-$(basename "$target").md"

# --- Assemble the non-Markovian context ---
{
  printf '# Proposal: %s\n\n' "$target"
  printf 'proposal_id: %s\n' "$proposal_id"
  printf 'generated: %s\n\n' "$ts"

  printf '## 1. Why this proposal exists\n\n'
  printf 'This is a non-Markovian proposal — it was assembled with the full iteration history\n'
  printf 'for this target so the proposing model reads WHY prior attempts failed, not just\n'
  printf 'that they failed. This is the #1 lever (meta-harness): full-history search beats\n'
  printf 'best-of-N and model hopping.\n\n'

  printf '## 2. Iteration history for this target (the "why")\n\n'
  if [[ -f "$HISTORY" ]] && jq -e --arg t "$target" 'select(.target==$t)' "$HISTORY" >/dev/null 2>&1; then
    printf '```\n'
    "$ROOT/hooks/history.sh" why "$target" 2>/dev/null || echo "(no why digest available)"
    printf '```\n\n'
  else
    printf 'No prior iterations for this target. This is the first proposal.\n\n'
  fi

  printf '## 3. Latest self-diagnosis (relevant clusters)\n\n'
  last_diag="$(ls -t "$RUNTIME"/diagnosis-*.jsonl 2>/dev/null | head -1)"
  if [[ -n "$last_diag" && -f "$last_diag" ]]; then
    printf '```\n'
    jq -c '.' "$last_diag" 2>/dev/null | head -20 || echo "(diagnosis unparseable)"
    printf '```\n\n'
  else
    printf 'No diagnosis available yet. Run `hooks/diagnose.sh` to generate one.\n\n'
  fi

  printf '## 3.5. Latest reflection for this target (Reflexion, P9.2)\n\n'
  printf 'If a prior proposal for this target FAILED the gate, reflect-retry.sh staged a\n'
  printf 'reflection. Read it BEFORE writing the proposed edit (section 6) — do not repeat\n'
  printf 'the dead end the reflection already diagnosed. This is the inline retry-with-\n'
  printf 'reflection pattern: retry WITH the reflection as context, not blind.\n\n'
  last_reflection="$(ls -t "$FORGE"/reflections/*-reflection.md 2>/dev/null | head -1)"
  if [[ -n "$last_reflection" && -f "$last_reflection" ]]; then
    printf '```\n'
    bat -p --paging=never "$last_reflection" 2>/dev/null || sed -n '1,$p' "$last_reflection"
    printf '\n```\n\n'
  else
    printf 'No prior reflection for this target. This is the first proposal (or the last\n'
    printf 'gate PASS reset the retry counter).\n\n'
  fi

  printf '## 3.6. Textual gradient (TextGrad, P9.3)\n\n'
  printf 'If a reflection (section 3.5) exists, textgrad.sh staged a PRESCRIPTIVE gradient\n'
  printf '— a diff-oriented criticism of the current target text w.r.t. the eval loss.\n'
  printf 'Anchor on it when writing the proposed edit (section 6): it says WHICH lines to\n'
  printf 'change and HOW, distinct from the reflection narrative (what failed and why).\n'
  printf 'Per the do-not-adopt list, textgrad is NOT the sole optimizer — it is one of an\n'
  printf 'ensemble (this gradient + the non-Markovian history + the reflection).\n\n'
  last_gradient="$(ls -t "$FORGE"/gradients/*-gradient.md 2>/dev/null | head -1)"
  if [[ -n "$last_gradient" && -f "$last_gradient" ]]; then
    printf '```\n'
    bat -p --paging=never "$last_gradient" 2>/dev/null || sed -n '1,$p' "$last_gradient"
    printf '\n```\n\n'
  else
    printf 'No gradient for this target (textgrad.sh runs only when a reflection exists).\n\n'
  fi

  printf '## 4. Staged distill candidates\n\n'
  if [[ -n "$candidate" ]]; then
    printf 'Anchored on candidate: %s\n\n' "$candidate"
  fi
  forge_files="$(fd -e md . "$FORGE" --max-depth 1 2>/dev/null | head -5 || true)"
  if [[ -n "$forge_files" ]]; then
    printf '```\n'
    printf '%s\n' "$forge_files"
    printf '```\n\n'
  else
    printf 'No staged candidates in forge/. Run `hooks/distill.sh` to mine some.\n\n'
  fi

  printf '## 5. Current content of %s\n\n' "$target"
  printf '```%s\n' "$(basename "$target" | sed 's/.*\.//')"
  sed -n '1,120p' "$target"
  printf '\n```\n\n'

  printf '## 6. Proposed edit\n\n'
  printf '> FILL IN: the proposing model writes the targeted edit here. Read the iteration\n'
  printf '> history above first -- do not repeat dead ends. The edit must be evidence-backed.\n\n'
  printf '> The edit is a UNIFIED DIFF against the current file content shown in section 5.\n'
  printf '> Use hunk headers (@@), context lines (leading space), removed lines (leading -),\n'
  printf '> and added lines (leading +). The gate never mutates the live hook to test a\n'
  printf '> proposal: `hooks/trial-apply.sh` extracts this diff block, applies it to a COPY\n'
  printf '> of the target at .harness/forge/trial/<proposal_id>/, and passes that candidate\n'
  printf '> to `eval-run.sh --candidate`. Remove this `> FILL IN` line once the diff is written\n'
  printf '> -- a leftover placeholder is rejected by trial-apply.sh.\n\n'
  printf '```diff\n'
  printf -- '-- <original line>\n'
  printf -- '++ <proposed line>\n'
  printf '```\n\n'

  printf '## 7. Rollback contract (C1 safety gate)\n\n'
  printf '> REQUIRED: the exact action to revert this change if it regresses post-deploy.\n'
  printf '> Specify: file+baseline to restore, commit to revert, or deploy-watch metric to monitor.\n\n'
  printf '> file: (path to restore on revert)\n'
  printf '> baseline: (git commit SHA or baseline value to compare against)\n'
  printf '> deploy_watch_metric: (heldout-lift, test-pass-rate, latency, etc.)\n\n'

  printf '## 8. Invariants touched (C1 safety gate)\n\n'
  printf '> REQUIRED: which protected invariants does this change affect?\n'
  printf '> List the invariant name and whether this change touches (read/write/bypass) it.\n'
  printf '> If none, write "none".\n\n'
  printf '> Invariants this change affects:\n'
  printf '> - (e.g., "self-mod-human-review: write — proposal is staged for human review")\n\n'

  printf '## 9. Predicted impact\n\n'
  printf '> FILL IN: which metric do you expect to move, by how much, and why?\n'
  printf -- '- metric: \n- predicted_delta: \n- rationale: \n\n'

  printf '## 10. Constraint gate checklist\n\n'
  printf 'Before this proposal can be reviewed, hooks/gate.sh must pass:\n'
  printf -- '- [ ] tests pass\n'
  printf -- '- [ ] skill size <=15KB (if target is a skill)\n'
  printf -- '- [ ] cache compatibility (no mid-conversation change)\n'
  printf -- '- [ ] semantic preservation (behavior unchanged on held-out set)\n'
  printf -- '- [ ] Pareto: better on >=1 axis without regressing others\n'
  printf -- '- [ ] rollback contract: non-empty (C1 safety gate)\n'
  printf -- '- [ ] invariants touched: declared (C1 safety gate)\n'
  printf -- '- [ ] no protected surface mutations (C1 safety gate)\n\n'

  printf '## 11. Reviewer instructions (evaluator ≠ agent)\n\n'
  printf 'The proposing model is NOT the reviewer. The host agent reviews this proposal,\n'
  printf 'runs `hooks/gate.sh %s`, and if it passes, opens a human-reviewed PR.\n' "$proposal_id"
  printf 'Never commit directly. If the gate fails, record the regression in history and\n'
  printf 'the proposer will read it next time (non-Markovian learning).\n'
} > "$out"

# Record the proposal in history.
"$ROOT/hooks/history.sh" add "$target" "$proposal_id" "proposed" "" "" "proposal assembled at $out" 2>/dev/null || true

echo "proposal assembled: $out"
echo "  proposal_id: $proposal_id"
echo "  target: $target"
echo "  next: fill in the edit + predicted impact, then run hooks/gate.sh $proposal_id"
exit 0
