#!/usr/bin/env bash
# Claude Code statusline:
#   [project] msg:N  ↓<rtk_saved>tok
#
# rtk savings cached for 60s to avoid spawning rtk on every render.

set -uo pipefail

# Tier-warn (ADR-0050): flag apex-priced sessions so routine work moves to sonnet.
INPUT=$(cat 2>/dev/null || true)
MODEL=$(printf '%s' "$INPUT" | jq -r '.model.id // .model.display_name // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
APEX=""
case "$MODEL" in *opus*|*fable*) APEX="  APEX-\$\$ routine?->/model sonnet" ;; esac

count=$(cat "$HOME/.claude/.session-msg-count" 2>/dev/null || echo 0)
project=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")

CACHE="$HOME/.claude/.rtk-savings.cache"
NOW=$(date +%s)
saved=""

if [ -f "$CACHE" ]; then
  CACHED_AT=$(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  if [ $((NOW - CACHED_AT)) -lt 60 ]; then
    saved=$(cat "$CACHE")
  fi
fi

if [ -z "$saved" ] && command -v rtk &>/dev/null; then
  raw=$(rtk gain --format json 2>/dev/null | jq -r '.summary.total_saved // empty' 2>/dev/null || echo "")
  if [ -n "$raw" ] && [ "$raw" != "null" ]; then
    if [ "$raw" -ge 1000000 ]; then
      saved="$(awk "BEGIN{printf \"%.1fM\", $raw/1000000}")"
    elif [ "$raw" -ge 1000 ]; then
      saved="$(awk "BEGIN{printf \"%.0fK\", $raw/1000}")"
    else
      saved="$raw"
    fi
    echo -n "$saved" > "$CACHE"
  fi
fi

if [ -n "$saved" ]; then
  echo "[$project] msg:$count  ↓${saved}tok$APEX"
else
  echo "[$project] msg:$count$APEX"
fi
