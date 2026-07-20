#!/usr/bin/env bash
# SessionStart hook: nudge when the live ~/.claude harness has uncommitted drift
# vs the tracked ~/.claude-env source. Non-blocking, silent when in sync.
# Turns "harness edits MUST commit to claude-env" from a memory rule into a
# machine-enforced alert (ADR-0041). Modeled on main-release-drift-nudge.sh.
set -u
cat >/dev/null 2>&1 || true   # consume the stdin envelope (unused)

CHECK="$HOME/.claude-env/hooks/check-harness-drift.sh"
[ -x "$CHECK" ] || exit 0

DRIFT="$("$CHECK" 2>/dev/null)" || true
if [ -n "$DRIFT" ]; then
  N=$(printf '%s\n' "$DRIFT" | grep -c .)
  jq -n --arg n "$N" \
    '{"systemMessage": "⚠ \($n) harness file(s) drift between live ~/.claude and tracked ~/.claude-env. Run `bash ~/.claude-env/hooks/check-harness-drift.sh`, then sync + commit before the next pull clobbers them."}'
fi
exit 0
