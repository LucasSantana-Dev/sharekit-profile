#!/usr/bin/env bash
# Harness drift detector — ADR-0041 topology guard.
# Reports files that diverge between the LIVE runtime harness (~/.claude) and the
# TRACKED source (~/.claude-env): files that differ (live edited, not committed)
# or live-only files (would be lost on machine reset / clobbered by sync pull).
# Catches exactly the class that bit us: the 39-live-vs-18-tracked agent
# divergence and the secret-blocker edited live but not committed.
#
#   bash hooks/check-harness-drift.sh            # default ~/.claude vs ~/.claude-env
#   bash hooks/check-harness-drift.sh LIVE TRACKED
#
# Exit 0 = in sync, exit 1 = drift found (prints one line per drifted file).
set -uo pipefail
LIVE="${1:-$HOME/.claude}"
TRACKED="${2:-$HOME/.claude-env}"

# Known-intentional live-only files — excluded from drift (NOT mistakes):
#   rtk-rewrite.sh       hash-locked, managed by the rtk binary, not claude-env
#   criativaria-brain-*  deprecated orphans (project-local sync superseded them)
#   archive / agents-archive  retired content, not deployed
EXCLUDE_RE='(rtk-rewrite\.sh|criativaria-brain-[a-z]+\.sh|/archive/|agents-archive)'

[ -d "$LIVE" ] && [ -d "$TRACKED" ] || { echo "SKIP: $LIVE or $TRACKED missing"; exit 0; }

drift=0
for sub in agents hooks; do
  [ -d "$LIVE/$sub" ] && [ -d "$TRACKED/$sub" ] || continue
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '%s' "$f" | grep -qE "$EXCLUDE_RE" && continue
    rel="$sub/$(basename "$f")"
    if [ ! -e "$TRACKED/$rel" ]; then
      echo "UNTRACKED  $rel  (live-only — commit to claude-env or it's lost on reset)"
      drift=1
    elif ! diff -q "$f" "$TRACKED/$rel" >/dev/null 2>&1; then
      echo "DRIFT      $rel  (live edit not synced to claude-env)"
      drift=1
    fi
  done < <(find "$LIVE/$sub" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.md' \) 2>/dev/null)
done

exit "$drift"
