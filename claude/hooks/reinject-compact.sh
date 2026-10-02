#!/usr/bin/env bash
# reinject-compact.sh: SessionStart hook, matcher "compact".
#
# Compaction summarizes lossily: exact IDs, PR numbers, the operator's own words and
# mid-session decisions get paraphrased away (CCA-F Task 5.1, "case facts" block).
# This re-injects, verbatim, what was saved for THIS session before the compact:
#   1. the per-session facts file the agent appends to (IDs, PR#, decisions, constraints)
#   2. the auto-handoff pre-compact-summary.sh wrote seconds earlier
#   3. a pointer to the precompact memory snapshot (merged from post-compact-snapshot-surface.sh)
#
# History: until 2026-10-01 this ran on PostCompact and re-injected ~/.claude/memory/CORE.md.
# That file never existed (22 `postcompact-no-core` events in trajectory.jsonl), and
# PostCompact stdout does not reach the model anyway. SessionStart(compact) stdout does.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
SID=$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null)
[ -z "$SID" ] && exit 0
CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null)

FACTS="$HOME/.claude/.harness/runtime/facts-$SID.md"
PROJ=$(cd "${CWD:-$PWD}" 2>/dev/null && "$HOME/.claude/skills/handoff/bin/handoffs" dir 2>/dev/null)
AUTO="${PROJ:-$HOME/.claude/handoffs/_sem-projeto}/auto/$SID.md"

# Capped so a runaway file cannot flood the fresh context it is trying to protect.
if [ -s "$FACTS" ]; then
  printf '# Session facts (verbatim, kept across compaction)\n\n'
  head -c 6000 "$FACTS"
  printf '\n\n'
fi
if [ -s "$AUTO" ]; then
  printf '# Pre-compact auto-handoff\n\n'
  head -c 6000 "$AUTO"
  printf '\n'
fi
# Pointer to the precompact memory snapshot written by memory-extract.sh (this compact's, last 5 min).
JSONL=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SID}.jsonl" -type f 2>/dev/null | head -1)
if [ -n "$JSONL" ]; then
  SNAP=$(find "$(dirname "$JSONL")/memory/" -maxdepth 1 -name 'precompact_snapshot_*.md' -mmin -5 -type f 2>/dev/null | sort | tail -1)
  if [ -n "$SNAP" ]; then
    DESC=$(awk '/^description:/{sub(/^description: /,""); print; exit}' "$SNAP" 2>/dev/null)
    printf 'PreCompact memory snapshot: %s (%s markers). %s. Read it to recover earlier decisions.\n' \
      "$SNAP" "$(grep -c '^- \*\*\[' "$SNAP" 2>/dev/null || true)" "${DESC:-}"
  fi
fi
# Team Mode is announced once per session (team-mode-guard.sh); re-send it after compaction.
for TM in "${TMPDIR:-/tmp}/.team-mode-guard-${SID}-"*; do [ -s "$TM" ] && { cat "$TM"; printf '\n'; }; done
printf 'Keep durable facts (IDs, PR numbers, decisions, constraints) in %s: it survives compaction verbatim.\n' "$FACTS"
exit 0
