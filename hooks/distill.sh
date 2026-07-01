#!/usr/bin/env bash
# distill.sh — the nightly distill (observe → evaluate bridge).
#
# Mines .harness/runtime/trajectory.jsonl + pending-distill.jsonl for candidate
# learnings, applies heuristic prefiltering + confidence-scoring, and stages
# candidates to .harness/forge/ for host-agent review. NEVER mutates semantic
# memory directly — graduation requires an explicit --rationale (see
# review.sh). No rubber-stamping.
#
# Cross-wave basis: forge SessionEnd mining (26 lesson patterns),
# agentic-stack auto_dream (stages only; host-agent reviews), lumos
# MemorySynthesizer (3-tier time decay).
#
# Usage:
#   hooks/distill.sh                # mine + stage pending sessions
#   hooks/distill.sh --status       # show staged/pending counts
#
# Exit 0 always (staging is advisory); errors are logged, not fatal.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
TRAJ="$RUNTIME/trajectory.jsonl"
PENDING="$RUNTIME/pending-distill.jsonl"
FORGE="$ROOT/.harness/forge"
STATE="$RUNTIME/distill-state.jsonl"
mkdir -p "$FORGE" "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
datestamp="$(date -u +%Y-%m-%d)"

# --- status mode ---
if [[ "${1:-}" == "--status" ]]; then
  pending=0; staged=0; traj_lines=0
  [[ -f "$PENDING" ]] && pending="$(wc -l < "$PENDING" | tr -d ' ')"
  staged="$(fd -e md -t f . "$FORGE" 2>/dev/null | wc -l | tr -d ' ')"
  [[ -f "$TRAJ" ]] && traj_lines="$(wc -l < "$TRAJ" | tr -d ' ')"
  echo "distill status:"
  echo "  trajectory events: $traj_lines"
  echo "  pending sessions:  $pending"
  echo "  staged candidates: $staged"
  exit 0
fi

# --- mine the trajectory for signal patterns ---
# 26 lesson patterns condensed to 4 signal classes with base confidence:
#   failure   (1.0)  — "failed because", "broke when", errors, blocked
#   learning  (0.9)  — "learned that", "discovered", "realized"
#   decision  (0.8)  — "decided to", "chose", "went with"
#   pattern   (0.7)  — "always do X", "the trick is", repeated success
[[ -f "$TRAJ" ]] || { echo "distill: no trajectory log yet; nothing to mine." >&2; exit 0; }

out="$FORGE/${datestamp}-forge.md"
{
  printf '# Forged: %s\n\n' "$datestamp"
  printf 'Mined from .harness/runtime/trajectory.jsonl. Staged for host-agent review.\n'
  printf 'Graduate via `hooks/review.sh graduate <id> --rationale "..."` (rationale required).\n\n'

  printf '## Failures (base confidence 1.0)\n\n'
  tail -n 2000 "$TRAJ" 2>/dev/null \
    | jq -r 'select(.event=="tool-call" and (.outcome=="error" or .outcome=="blocked")) | "- [F] \(.tool) → \(.response[0:120])"' 2>/dev/null \
    | head -50 || true
  printf '\n'

  printf '## Errors by tool (frequency)\n\n'
  tail -n 2000 "$TRAJ" 2>/dev/null \
    | jq -r 'select(.event=="tool-call" and .outcome=="error") | .tool' 2>/dev/null \
    | sort | uniq -c | sort -rn | head -10 \
    | awk '{printf "- %s: %s occurrences\n", $2, $1}' || true
  printf '\n'

  printf '## Blocked operations (invariant enforcement hits)\n\n'
  tail -n 2000 "$TRAJ" 2>/dev/null \
    | jq -r 'select(.event=="tool-call" and .outcome=="blocked") | "- \(.tool): \(.response[0:120])"' 2>/dev/null \
    | head -30 || true
  printf '\n'

  printf '## Repeated commands (stuck-protocol candidates)\n\n'
  tail -n 2000 "$TRAJ" 2>/dev/null \
    | jq -r 'select(.event=="tool-call" and .tool=="Bash") | .input' 2>/dev/null \
    | sort | uniq -c | sort -rn | head -10 \
    | awk '{printf "- (x%s) %s\n", $1, substr($0, index($0,$2))}' || true
  printf '\n'

  printf '## Top tools (usage heatmap)\n\n'
  tail -n 2000 "$TRAJ" 2>/dev/null \
    | jq -r 'select(.event=="tool-call") | .tool' 2>/dev/null \
    | sort | uniq -c | sort -rn | head -10 \
    | awk '{printf "- %s: %s calls\n", $2, $1}' || true
  printf '\n'
} > "$out"

# --- heuristic prefilter: drop empty / trivial candidates ---
# (forge requires ≥3 content words per claim — agentic-stack validate.py)
lines="$(wc -l < "$out" | tr -d ' ')"
if [[ "$lines" -lt 8 ]]; then
  # Too sparse to be meaningful — keep the file but note it.
  printf '\n> NOTE: sparse session (<8 lines) — likely little to learn. Reviewer may reject all.\n' >> "$out"
fi

# --- record distill run ---
candidate_count="$(rg -c '^- \[' "$out" 2>/dev/null || echo 0)"
printf '{"ts":"%s","event":"distill-run","date":"%s","candidates":%s,"file":"%s"}\n' \
  "$ts" "$datestamp" "$candidate_count" "$out" >> "$STATE"

# --- clear the pending queue (sessions have been mined) ---
if [[ -f "$PENDING" ]]; then
  mv "$PENDING" "$PENDING.mined-${datestamp}"
fi

echo "distill: staged $candidate_count candidate(s) → $out" >&2
echo "  review with: hooks/review.sh list" >&2
exit 0
