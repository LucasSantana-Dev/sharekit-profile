#!/usr/bin/env bash
# adoption-panel.sh - local-only adoption signal panel (team-expansion opp 10).
#
# PRIVACY MODEL (the decision that unblocked this): all signals are computed
# from files on THIS machine and printed to THIS terminal. No network calls,
# no telemetry egress, no user-identifying aggregation. Session transcripts
# never leave disk; only aggregate counts are printed. Teams that want
# org-level numbers can each run this locally and share the summary by hand.
#
# Signals (all local):
#   skills:   invocations per skill, from Claude Code session JSONLs
#   hooks:    firing counts from known hook log files
#   sessions: session count + active days in the window
#
# Usage: bash scripts/adoption-panel.sh [--days N] [--projects DIR]
set -uo pipefail

DAYS=30
PROJECTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --projects) PROJECTS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "== adoption panel (local-only, last $DAYS days) =="

if [ ! -d "$PROJECTS" ]; then
  echo "no session logs at $PROJECTS (set --projects or CLAUDE_PROJECTS_DIR)"
else
  FILES=$(find "$PROJECTS" -name '*.jsonl' -mtime "-$DAYS" 2>/dev/null | wc -l | tr -d ' ')
  echo "sessions: $FILES files with activity"

  echo "top skills:"
  find "$PROJECTS" -name '*.jsonl' -mtime "-$DAYS" -print0 2>/dev/null \
    | xargs -0 grep -ho '"name":"Skill","input":{"skill":"[a-z0-9-]*"' 2>/dev/null \
    | sed 's/.*"skill":"//;s/"//' \
    | sort | uniq -c | sort -rn | head -10 \
    | awk '{printf "  %5d  %s\n", $1, $2}'
fi

echo "hook signals:"
for log in "$HOME/.claude/read-dedup.log"; do
  if [ -f "$log" ]; then
    echo "  $(basename "$log"): $(wc -l < "$log" | tr -d ' ') entries"
  fi
done
echo "(panel complete - nothing left this machine)"
