#!/usr/bin/env bash
# compaction-guard.sh - PreCompact hook: hybrid context control (P4).
#
# The Wave-5 context-engineering track converged on one rule that the existing
# snapshot-compact.sh does not enforce: compaction must PRESERVE tool-call /
# result adjacency. If a compaction summary drops a tool result but keeps the
# tool call (or vice versa), the model loses the pairing and downstream
# execution drifts (championswimmer/pi-context-prune, OpenHands condenser).
#
# This hook runs alongside snapshot-compact.sh on PreCompact and does three
# advisory things (it NEVER blocks - exit 0 always):
#
#   1. ADJACENCY AUDIT. Scan the recent trajectory for tool-call events whose
#      result is missing or out of order. Emit a compaction directive listing
#      the call/result pairs that must be kept together through compaction.
#   2. BUDGET THRESHOLD. The redis/agent-memory-server pattern triggers
#      summarization at ~70% context utilization. If the payload exposes a
#      token/usage figure, flag when compaction is firing late (>85%) so the
#      threshold can be tuned down toward the cache-friendly band.
#   3. CACHE-PREFIX STABILITY. agentcache (80-99% cache rates) shows that
#      compaction should rewrite the VOLATILE suffix and leave the stable
#      prefix intact. Emit a directive to keep the system-prompt prefix
#      (rules/constraints) verbatim so the prompt cache survives compaction.
#
# Output: a compaction directive at .harness/runtime/compact/directive-<ts>.md
# that the PostCompact reinject path (reinject-compact.sh) can surface.
#
# Wire in claude/settings.json PreCompact alongside snapshot-compact.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
SNAP_DIR="$RUNTIME/compact"
TRAJ="$RUNTIME/trajectory.jsonl"
mkdir -p "$SNAP_DIR"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"

# --- status mode -------------------------------------------------------------
if [[ "${1:-}" == "--status" ]]; then
  last="$(ls -t "$SNAP_DIR"/directive-*.md 2>/dev/null | head -1)"
  [[ -n "$last" ]] || { echo "no compaction directives yet"; exit 0; }
  bat -p "$last" 2>/dev/null || cat "$last"
  exit 0
fi

input="$(cat 2>/dev/null || true)"
directive="$SNAP_DIR/directive-${stamp}.md"

# --- 1. Tool-call / result adjacency audit ----------------------------------
# Walk the recent trajectory; a tool-call event should be followed by a result
# (outcome present). Count calls whose immediate successor is not a result for
# the same tool - those are the pairs most at risk during compaction.
unpaired=0
pairs=""
if [[ -f "$TRAJ" ]]; then
  # Pull the last 200 tool-call events as compact lines: ts \t tool \t outcome
  mapfile -t recent < <(tail -n 200 "$TRAJ" 2>/dev/null \
    | jq -r 'select(.event=="tool-call") | "\(.tool // "?")\t\(.outcome // "none")"' 2>/dev/null || true)
  for line in "${recent[@]}"; do
    tool="${line%%$'\t'*}"
    outcome="${line##*$'\t'}"
    if [[ "$outcome" == "none" || -z "$outcome" ]]; then
      unpaired=$((unpaired + 1))
      pairs="${pairs}- ${tool}: call with no recorded result (keep its result adjacent if it exists)\n"
    fi
  done
fi

# --- 2. Budget threshold check ----------------------------------------------
# Try to read a utilization/token figure from the payload. Different harnesses
# expose it under different keys; we treat any of them as advisory.
util=""
if [[ -n "$input" ]]; then
  util="$(printf '%s' "$input" | jq -r '
    .context_utilization
    // .usage.percent
    // .metadata.context_pct
    // empty' 2>/dev/null || true)"
fi
budget_note=""
if [[ -n "$util" ]]; then
  # Strip a trailing % if present.
  util_num="${util%\%}"
  if awk "BEGIN{exit !($util_num > 85)}" 2>/dev/null; then
    budget_note="Compaction is firing LATE (${util_num}% > 85%). The cache-friendly band is ~70% (redis pattern); consider lowering the compaction threshold so summaries happen before the window is saturated."
  else
    budget_note="Compaction firing at ${util_num}% (within/under the ~70-85% band)."
  fi
fi

# --- Write the compaction directive ------------------------------------------
{
  printf '# Compaction directive - %s\n\n' "$ts"
  printf 'Advisory guidance for this compaction (P4 hybrid context control).\n'
  printf 'compaction-guard never blocks; it shapes HOW compaction should run.\n\n'

  printf '## 1. Preserve tool-call / result adjacency\n\n'
  printf 'Keep every tool call paired with its result through compaction. Dropping\n'
  printf 'one side of a pair causes downstream execution drift (pi-context-prune,\n'
  printf 'OpenHands condenser).\n\n'
  if [[ "$unpaired" -gt 0 ]]; then
    printf 'At-risk pairs detected in the recent trajectory (%s):\n\n' "$unpaired"
    printf '%b\n' "$pairs"
  else
    printf 'No unpaired tool calls detected in the recent trajectory.\n\n'
  fi

  printf '## 2. Budget threshold\n\n'
  if [[ -n "$budget_note" ]]; then
    printf '%s\n\n' "$budget_note"
  else
    printf 'No context-utilization figure exposed in the payload; threshold not assessed.\n\n'
  fi

  printf '## 3. Cache-prefix stability\n\n'
  printf 'Rewrite the VOLATILE suffix (recent turns) and leave the STABLE prefix\n'
  printf '(system prompt, rules, constraints) verbatim so the prompt cache survives\n'
  printf 'compaction (agentcache 80-99%% cache rates). Do not reorder or reword the\n'
  printf 'CORE memory block re-injected by reinject-compact.sh.\n'
} > "$directive"

# Record a machine-readable marker too.
printf '{"ts":"%s","event":"compaction-directive","unpaired":%s,"util":"%s","directive":"%s"}\n' \
  "$ts" "$unpaired" "${util:-}" "$directive" >> "$RUNTIME/compaction-guard.jsonl"

echo "compaction-guard: directive written ($unpaired at-risk pairs): $directive" >&2
exit 0
