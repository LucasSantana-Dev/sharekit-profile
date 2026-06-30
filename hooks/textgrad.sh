#!/usr/bin/env bash
# textgrad.sh — TextGrad-style textual-gradient optimization (P9.3).
#
# Complements (does NOT replace) the evolutionary proposer (propose.sh) and the
# inline reflection (reflect-retry.sh). The three form a layered optimize path:
#
#   - propose.sh      — non-Markovian SEARCH over edits (reads WHY prior failed)
#   - reflect-retry.sh — narrative DIAGNOSIS of a single failure (Reflexion)
#   - textgrad.sh     — PRESCRIPTIVE textual GRADIENT (TextGrad, Nature 2025):
#                        forward pass (the failed proposal) -> loss (gate FAIL)
#                        -> backward pass (LLM-generated criticism of the
#                        current hook/prompt text w.r.t. the loss) -> step
#                        (a diff-oriented update suggestion).
#
# Where the reflection says "what failed and why" (narrative), the gradient says
# "which lines/sections of the target text to change and how" (prescription).
# The proposing model reads BOTH in propose.sh (section 3.5 reflection + section
# 3.6 gradient) before writing its edit, so it anchors on the gradient in
# addition to the non-Markovian history.
#
# Per docs/harness-research-synthesis.md do-not-adopt #7: textgrad is NOT the
# sole optimizer — it is one of an ensemble (TextGrad + the evolutionary
# proposer + the reflection). It is opt-in: the cycle runs it only when a gate
# FAIL has a reflection (one gradient per reflection), keeping it bounded.
#
# The gradient is ADVISORY: never blocks (exit 0), never mutates memory, never
# auto-applies. Stages to .harness/forge/gradients/ for host-agent review.
#
# Usage:
#   hooks/textgrad.sh <target> [proposal-id]    # generate a textual gradient
#   hooks/textgrad.sh --status                  # print the last gradient
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
GRADIENTS="$FORGE/gradients"
REFLECTIONS="$FORGE/reflections"
HISTORY="$RUNTIME/iteration-history.jsonl"
TRAJ="$RUNTIME/trajectory.jsonl"
mkdir -p "$GRADIENTS" "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- CLI: --status (print the last gradient) ---------------------------------
if [[ "${1:-}" == "--status" ]]; then
  last="$(ls -t "$GRADIENTS"/*.md 2>/dev/null | head -1)"
  [[ -n "$last" ]] || { echo "no gradients yet"; exit 0; }
  bat -p "$last" 2>/dev/null || cat "$last"
  exit 0
fi

target="${1:-}"
pid="${2:-}"
[[ -n "$target" ]] || { echo "textgrad: requires <target> [proposal-id]" >&2; exit 2; }

# --- Read the latest reflection (the gradient is anchored on it) -------------
# The gradient is generated PER REFLECTION (one gradient per reflection). If
# there is no reflection for this target, the gradient has no loss signal to
# backpropagate through — skip gracefully.
last_reflection="$(ls -t "$REFLECTIONS"/*-reflection.md 2>/dev/null | head -1)"
if [[ -z "$last_reflection" || ! -f "$last_reflection" ]]; then
  echo "textgrad: no reflection for $target — nothing to backpropagate (run reflect-retry.sh first)" >&2
  exit 0
fi

# --- Read the failure context (the loss) -------------------------------------
# The latest gate-rejected / regressed iteration is the loss. The gradient
# criticizes the target text w.r.t. this loss.
fail_note=""
if [[ -f "$HISTORY" ]]; then
  fail_note="$(bash "$ROOT/hooks/history.sh" last "$target" 2>/dev/null | jq -r '.note // empty' 2>/dev/null)"
fi
why_digest=""
[[ -f "$HISTORY" ]] && why_digest="$(bash "$ROOT/hooks/history.sh" why "$target" 2>/dev/null)"

# --- Read the target's current content (the forward pass output) -------------
# The gradient criticizes THIS text. If the target doesn't exist on disk, the
# gradient has nothing to criticize — skip.
if [[ ! -f "$target" ]]; then
  echo "textgrad: target not found on disk: $target — cannot generate a gradient" >&2
  exit 0
fi
target_content="$(sed -n '1,80p' "$target" 2>/dev/null)"

digest="$GRADIENTS/${ts//[:]/-}-gradient.md"
machine="$GRADIENTS/${ts//[:]/-}-gradient.jsonl"

# --- Write the textual gradient ----------------------------------------------
# The TextGrad "backward pass": the proposing model / host agent fills the
# gradient — a structured criticism of the target text w.r.t. the eval loss,
# plus a diff-oriented update prescription. This hook assembles the context.
{
  printf '# Textual gradient — %s\n\n' "$ts"
  printf 'A TextGrad-style textual-gradient optimization pass for `%s` (proposal `%s`).\n' "$target" "${pid:-<none>}"
  printf 'This is the PRESCRIPTIVE layer (which lines/sections to change and how),\n'
  printf 'complementing the narrative reflection (what failed and why). The proposing\n'
  printf 'model reads BOTH in propose.sh (section 3.5 reflection + section 3.6 gradient)\n'
  printf 'before writing its edit. Per the do-not-adopt list, textgrad is NOT the sole\n'
  printf 'optimizer — it is one of an ensemble (TextGrad + evolutionary proposer +\n'
  printf 'reflection).\n\n'

  printf '## Loss signal (the gate FAIL being backpropagated)\n\n'
  printf -- '- target: `%s`\n' "$target"
  printf -- '- proposal: `%s`\n' "${pid:-<none>}"
  printf -- '- loss (fail reasons): %s\n\n' "${fail_note:-<none recorded>}"

  if [[ -n "$why_digest" ]]; then
    printf '## Prior iteration history (the WHY — do not repeat)\n\n'
    printf '```\n%s\n```\n\n' "$why_digest"
  fi

  printf '## Anchor reflection (the narrative diagnosis)\n\n'
  printf '```\n'
  bat -p "$last_reflection" 2>/dev/null || cat "$last_reflection"
  printf '\n```\n\n'

  printf '## Forward pass — current target text (the object of criticism)\n\n'
  printf '```%s\n' "$(basename "$target" | sed 's/.*\.//')"
  printf '%s\n' "$target_content"
  printf '```\n\n'

  printf '## Backward pass — textual gradient (fill in)\n\n'
  printf '> The proposing model / host agent fills the gradient. Read the loss + the\n'
  printf '> reflection + the current text above. Criticize the text w.r.t. the loss,\n'
  printf '> then prescribe a diff-oriented update. Distinct from the reflection\n'
  printf '> (narrative): this is PRESCRIPTIVE (which lines to change and how).\n\n'
  printf -- '- **criticism**: (which lines/sections of the target text contributed to the loss, and why)\n'
  printf -- '- **gradient_step**: (the concrete textual change to apply — a diff-oriented prescription)\n'
  printf -- '- **expected_loss_delta**: (how much of the loss this step should recover, and why)\n\n'

  printf '## How this gradient is used\n\n'
  printf 'propose.sh injects this gradient into section 3.6 of the next proposal for\n'
  printf '`%s`, so the proposing model anchors on the gradient in addition to the\n' "$target"
  printf 'non-Markovian history (section 2) and the reflection (section 3.5). One\n'
  printf 'gradient per reflection — textgrad.sh refuses to run without a reflection\n'
  printf '(no loss signal to backpropagate).\n'
} > "$digest"

# --- Write machine-readable gradient event -----------------------------------
{
  printf '{"ts":"%s","event":"gradient","target":"%s","proposal_id":"%s","anchor_reflection":"%s","loss":"%s"}\n' \
    "$ts" "$target" "${pid:-}" "$(basename "$last_reflection")" "${fail_note//\"/\\\"}"
} >> "$machine"

# --- Append a gradient event to the trajectory (the observe log) -------------
if [[ -f "$TRAJ" ]]; then
  printf '{"ts":"%s","event":"gradient","tool":"textgrad.sh","outcome":"gradient","target":"%s","proposal_id":"%s"}\n' \
    "$ts" "$target" "${pid:-}" >> "$TRAJ"
fi

# --- Record the gradient in iteration history --------------------------------
bash "$ROOT/hooks/history.sh" add "$target" "${pid:-gradient-$ts}" "gradient" "loss" "" \
  "textual gradient staged at $digest (anchored on $(basename "$last_reflection"))" 2>/dev/null || true

echo "textual gradient staged: $digest"
echo "  target: $target | anchored on reflection: $(basename "$last_reflection")"
echo "  next proposal for this target will read it via propose.sh section 3.6"
exit 0
