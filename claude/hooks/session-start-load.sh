#!/usr/bin/env bash
# session-start-load.sh — SessionStart hook.
# One responsibility from docs/hook-firing-order position 1:
#   1. Run the harness drift check (live ~/.claude vs tracked ~/.claude-env).
# (CORE.md load removed 2026-09-26: memory/CORE.md never existed, silent no-op.)
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

# Boundary marker so SessionEnd can scope its summary.
jq -nc --arg ts "$ts" '{ts: $ts, event: "session-boundary", direction: "start"}' >> "$TRAJ"
exit 0
