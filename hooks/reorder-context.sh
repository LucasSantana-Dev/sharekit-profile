#!/usr/bin/env bash
# reorder-context.sh — PostToolUse hook: LongContextReorder postprocessor.
#
# Models exhibit "lost-in-the-middle" degradation (Liu et al. 2024): information
# placed in the center of the context window is recalled less reliably than
# information at the start and end. This creates model-dependent variance —
# models with smaller effective attention windows produce inconsistent results
# when critical context lands mid-window.
#
# Mechanism (source: LlamaIndex LongContextReorder):
#   Reorder retrieved chunks so the most relevant appear at the START and END
#   of the context block, with decreasing relevance filling the middle. For N
#   chunks ranked by score descending, interleave: chunk[0], chunk[N-1],
#   chunk[1], chunk[N-2], ... This guarantees the two highest-signal chunks
#   occupy the attention-favorable positions regardless of model architecture.
#
# This hook fires on PostToolUse for retrieval-augmented tool calls. It reads
# the tool's JSON output, extracts chunks, reorders them, and emits the
# reordered result as a sidecar digest that the distill/diagnose path reads.
# It does NOT block (exit 0 always) — pure deterministic transformation.
#
# Wire in claude/settings.json PostToolUse with matcher for retrieval tools.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

REORDER_DIR="$RUNTIME/reordered-chunks"
mkdir -p "$REORDER_DIR"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

read_hook_stdin

tool_name="$(hook_field "$HOOK_INPUT" ".tool_name // .tool")"

# Only fire on retrieval-augmented tool calls.
case "$tool_name" in
  mcp__rag-index__*|mcp__rag_index__*|*rag_query*|*recall*|*context-pack*|*context_pack*) ;;
  *) exit 0 ;;
esac

# Extract chunks from the tool response. Support common shapes:
#   {"chunks": [{"score": 0.9, "id": "...", "content": "..."}, ...]}
#   {"results": [{"score": 0.9, "id": "...", "content": "..."}, ...]}
#   {"documents": [...]}
tool_response="$(hook_field_json "$HOOK_INPUT" ".tool_response // .tool_result // .result // empty" || echo 'null')"

# Try to find the chunks array in common locations.
chunks_json="$(printf '%s' "$tool_response" | jq -c '
  if type == "array" then .
  elif .chunks // .results // .documents then (.chunks // .results // .documents)
  elif .tool_response.chunks // .tool_response.results then (.tool_response.chunks // .tool_response.results)
  else []
  end' 2>/dev/null || echo '[]')"

chunk_count="$(printf '%s' "$chunks_json" | jq 'length' 2>/dev/null || echo 0)"

# Skip if no chunks or too many (large windows get no benefit from reordering).
if [[ "$chunk_count" -eq 0 ]] || [[ "$chunk_count" -gt 50 ]]; then
  exit 0
fi

# --- LongContextReorder algorithm ---
# Sort by score descending, then interleave: even-index chunks go to front in
# order, odd-index to back in reverse. This places the two highest-scoring
# chunks at positions 0 and N-1 (the attention-favorable positions).
reordered="$(printf '%s' "$chunks_json" | jq -c '
  # Sort by score descending (handle missing score as 0)
  sort_by(.score // 0) | reverse
  | . as $sorted
  | length as $n
  | [range(0; $n)] as $indices
  | reduce $indices[] as $i (
      {front: [], back: []};
      if $i % 2 == 0
      then .front += [$sorted[$i]]
      else .back = [$sorted[$i]] + .back
      end
    )
  | (.front + .back)
')"

# Write reordered chunks to a sidecar digest file for the distill/diagnose path.
digest_file="$REORDER_DIR/$(printf '%s' "$ts" | sed 's/[^0-9T]//g').json"
printf '%s' "$reordered" | jq -c --arg ts "$ts" --arg tool "$tool_name" --argjson n "$chunk_count" \
  '{ts: $ts, tool: $tool, chunk_count: $n, reordered_chunks: .}' > "$digest_file"

# Emit a stderr nudge so the agent knows reordering happened (advisory).
echo "reorder-context: reordered $chunk_count chunks (LongContextReorder) — digest at $digest_file" >&2

exit 0
