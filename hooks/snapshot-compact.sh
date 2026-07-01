#!/usr/bin/env bash
# snapshot-compact.sh — PreCompact hook.
# Snapshots the pre-compaction conversation state to .harness/runtime/compact/
# so that critical context can be recovered if compaction loses something.
# Mirrors the PreCompact contract in docs/hooks.md and the Wave-4 pattern
# (lumos L8 memory layer, gearbox context-compact.mjs, Totalum). Does not block.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP_DIR="$ROOT/.harness/runtime/compact"
mkdir -p "$SNAP_DIR"

input="$(sed -n '1,$p')"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
file="$SNAP_DIR/pre-${stamp}.json"

# Capture the incoming payload (prompt transcript excerpt) plus metadata.
printf '%s' "$input" | jq --arg ts "$ts" '{ts: $ts, payload: .}' > "$file" 2>/dev/null || {
  printf '%s' "$input" > "$file.raw"
  jq -nc --arg ts "$ts" --arg raw "$file.raw" '{ts: $ts, note: "non-json payload saved to .raw", raw: $raw}' > "$file"
}

echo "PreCompact snapshot written: $file" >&2
exit 0
