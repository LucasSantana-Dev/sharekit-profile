#!/usr/bin/env bash
# SessionEnd hook: fix any RAG drift introduced during this session.
#
# Runs fix-drift-loop.sh in foreground (session is ending, not blocking UX)
# then regenerates the weekly report so the next session starts with a
# fresh baseline. Skips if the index doesn't exist or Python is missing.
set -u

ROOT="$HOME/.claude/rag-index"
PY="$ROOT/venv/bin/python3"
LOG="$ROOT/drift-reindex.log"
LOOP="$ROOT/fix-drift-loop.sh"

[ -x "$PY" ] || exit 0
[ -f "$ROOT/index.sqlite" ] || exit 0
[ -x "$LOOP" ] || exit 0

# Run loop — foreground so session end waits for it (max ~15s typical)
"$LOOP" --foreground 2>>"$LOG"

# Regenerate weekly report baseline for next session
"$PY" "$ROOT/report.py" >/dev/null 2>&1 &

exit 0
