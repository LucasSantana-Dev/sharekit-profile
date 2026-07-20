#!/bin/bash
# Push to knowledge-brain after memory or graph change (phase5-routing.md)

set -e  # fail loud

BRAIN="${DEV_ROOT}/knowledge-brain"

# Mount guard (standards/knowledge-brain.md §1) — fail loud, never silent
if ! mount | grep -q "${DEV_ROOT}" || [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: external drive not mounted — knowledge-brain unreachable. Skip push." >&2
  exit 1
fi

# Check for changes
git -C "$BRAIN" add memory/ graphs/ 2>/dev/null
if git -C "$BRAIN" diff --cached --quiet 2>/dev/null; then
  echo "knowledge-brain: nothing to push"
else
  git -C "$BRAIN" commit -q -m "chore: knowledge-brain sync from session" && \
  git -C "$BRAIN" push -q && \
  echo "knowledge-brain pushed"
fi
