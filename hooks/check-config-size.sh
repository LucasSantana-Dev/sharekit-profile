#!/usr/bin/env bash
# check-config-size.sh: context-file size cap + local-override drift warning
# (team-expansion Phase 7).
#
# Engagement drops when CLAUDE.md grows past what the model actually reads
# (rollout research: >400 lines warn, >800 split). And in team repos the
# personal layer (settings.local.json) silently diverging from the committed
# team layer (.claude/settings.json) is the cross-developer drift class.
#
#   FAIL  CLAUDE.md or AGENTS.md > 800 lines
#   WARN  CLAUDE.md or AGENTS.md > 400 lines
#   WARN  settings.local.json overrides a committed settings.json key with a
#         different value (listed, advisory)
#
# Exit 1 on FAIL, 0 otherwise. No config files -> pass.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT"

fails=0
for f in CLAUDE.md AGENTS.md; do
  [ -f "$f" ] || continue
  lines="$(wc -l < "$f" | tr -d ' ')"
  if [ "$lines" -gt 800 ]; then
    echo "check-config-size: FAIL - $f has $lines lines (>800; split it, the model is skimming)" >&2
    fails=$((fails + 1))
  elif [ "$lines" -gt 400 ]; then
    echo "check-config-size: WARN - $f has $lines lines (>400; consider trimming)" >&2
  fi
done

COMMITTED=".claude/settings.json"
LOCAL=".claude/settings.local.json"
if [ -f "$COMMITTED" ] && [ -f "$LOCAL" ] && command -v jq >/dev/null 2>&1; then
  overlap="$(jq -rn \
    --slurpfile a "$COMMITTED" --slurpfile b "$LOCAL" \
    '($a[0] | keys) as $ka | [$ka[] | select($b[0][.] != null and $b[0][.] != $a[0][.])] | .[]' 2>/dev/null || true)"
  if [ -n "$overlap" ]; then
    echo "check-config-size: WARN - settings.local.json diverges from committed settings on: $(printf '%s' "$overlap" | paste -sd', ' -)" >&2
  fi
fi

[ "$fails" -gt 0 ] && exit 1
exit 0
