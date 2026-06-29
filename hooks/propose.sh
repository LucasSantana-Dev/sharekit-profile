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
TRAJ="$RUNTIME/trajectory.jsonl"
mkdir -p "$PROPOSALS" "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
date_tag="$(date -u +%Y-%m-%d)"

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
  printf '> history above first — do not repeat dead ends. The edit must be evidence-backed.\n\n'
  printf '```diff\n'
  printf -- '-- <original line>\n'
  printf -- '++ <proposed line>\n'
  printf '```\n\n'

  printf '## 7. Predicted impact\n\n'
  printf '> FILL IN: which metric do you expect to move, by how much, and why?\n'
  printf -- '- metric: \n- predicted_delta: \n- rationale: \n\n'

  printf '## 8. Constraint gate checklist\n\n'
  printf 'Before this proposal can be reviewed, hooks/gate.sh must pass:\n'
  printf -- '- [ ] tests pass\n'
  printf -- '- [ ] skill size <=15KB (if target is a skill)\n'
  printf -- '- [ ] cache compatibility (no mid-conversation change)\n'
  printf -- '- [ ] semantic preservation (behavior unchanged on held-out set)\n'
  printf -- '- [ ] Pareto: better on >=1 axis without regressing others\n\n'

  printf '## 9. Reviewer instructions (evaluator ≠ agent)\n\n'
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
