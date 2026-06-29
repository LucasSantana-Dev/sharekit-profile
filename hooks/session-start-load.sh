#!/usr/bin/env bash
# session-start-load.sh — SessionStart hook.
# Two responsibilities from docs/hook-firing-order position 1:
#   1. Run the harness drift check (live ~/.claude vs tracked ~/.claude-env).
#   2. Load CORE memory into the session as additional context.
# Fails open: missing files / missing mirror are non-blocking warnings.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRAJ="$ROOT/.harness/runtime/trajectory.jsonl"
mkdir -p "$(dirname "$TRAJ")"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. Drift check (reuses the existing script; non-blocking).
if [[ -x "$ROOT/hooks/check-harness-drift.sh" ]]; then
  if ! "$ROOT/hooks/check-harness-drift.sh" >/tmp/sk-drift.$$ 2>&1; then
    echo "WARN: harness drift detected at SessionStart — see /tmp/sk-drift.$$:" >&2
    sed 's/^/  /' /tmp/sk-drift.$$ >&2
  fi
  rm -f /tmp/sk-drift.$$
fi

# 2. Load CORE memory.
mem_root="${BRAIN_ROOT:-$HOME/.claude/memory}"
core_file=""
for cand in "$mem_root/CORE.md" "$ROOT/claude/memory-structure/examples/CORE.md"; do
  [[ -f "$cand" ]] && core_file="$cand" && break
done
if [[ -n "$core_file" ]]; then
  printf '# CORE memory (SessionStart load)\n\n'
  cat "$core_file"
  printf '\n\n---\n^ Loaded by hooks/session-start-load.sh.\n'
fi

# Boundary marker so SessionEnd can scope its summary.
jq -nc --arg ts "$ts" '{ts: $ts, event: "session-boundary", direction: "start"}' >> "$TRAJ"
exit 0
