#!/usr/bin/env bash
# Stop hook: detect that a /hotfix Phase 10 completed in this session and
# nudge /incident-response Phase 3 (post-mortem) before the user closes the session.
#
# A composite/skill writes its phase completion to
# ~/.claude/state/hotfix-tracker.jsonl, one line per phase. This hook reads
# the tail, finds the most recent /hotfix run, and decides whether
# the incident post-mortem (incident-response Phase 3) has run yet.
#
# If a /hotfix Phase 10 (cherry-pick to release) completed in the last 6h AND
# no post-mortem ran after it, emit the nudge.
#
# Cheap (<50ms): bounded tail of a JSONL file. Never blocks.
set -uo pipefail
command -v jq &>/dev/null || exit 0

TRACKER_FILE="$HOME/.claude/state/hotfix-tracker.jsonl"
[ -f "$TRACKER_FILE" ] || exit 0

# Tail the last 50 lines; that's far more than enough to cover one session
TAIL=$(tail -n 50 "$TRACKER_FILE" 2>/dev/null) || exit 0
[ -z "$TAIL" ] && exit 0

# Find the most recent /hotfix Phase 10 completion timestamp
LAST_HOTFIX_DONE=$(printf '%s\n' "$TAIL" \
  | jq -r 'select(.composite == "hotfix" and .phase == 10 and .status == "done") | .ts' 2>/dev/null \
  | tail -1)

[ -z "$LAST_HOTFIX_DONE" ] && exit 0

# Find the most recent post-mortem completion timestamp
# (incident-response Phase 3, or legacy incident-followup runs).
LAST_FOLLOWUP_DONE=$(printf '%s\n' "$TAIL" \
  | jq -r 'select((( .composite == "incident-response" and ((.phase|tostring) == "3")) or .composite == "incident-followup") and .status == "done") | .ts' 2>/dev/null \
  | tail -1)

# Compare timestamps. If followup is after hotfix, we're clean.
if [ -n "$LAST_FOLLOWUP_DONE" ]; then
  HF_EPOCH=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$LAST_HOTFIX_DONE" '+%s' 2>/dev/null \
             || date -d "$LAST_HOTFIX_DONE" '+%s' 2>/dev/null || echo 0)
  FU_EPOCH=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$LAST_FOLLOWUP_DONE" '+%s' 2>/dev/null \
             || date -d "$LAST_FOLLOWUP_DONE" '+%s' 2>/dev/null || echo 0)
  if [ "$FU_EPOCH" -ge "$HF_EPOCH" ]; then
    exit 0  # followup already covers this hotfix
  fi
fi

# Check the 6-hour cooldown — the post-mortem defers if bleed isn't stopped
HF_EPOCH=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$LAST_HOTFIX_DONE" '+%s' 2>/dev/null \
           || date -d "$LAST_HOTFIX_DONE" '+%s' 2>/dev/null || echo 0)
NOW=$(date +%s)
HOURS_SINCE=$(( (NOW - HF_EPOCH) / 3600 ))

if [ "$HOURS_SINCE" -lt 6 ]; then
  # Bleed too fresh; just record the pending state, do not nudge
  exit 0
fi

# Once-per-session flag to prevent looping on the decision:block
# Use hotfix timestamp as the identifier so the flag persists across sessions
# until post-mortem is actually run
STATE_DIR="$HOME/.claude/.state"; mkdir -p "$STATE_DIR"
ACTION_FLAG="$STATE_DIR/hotfix-followup-action-$(echo "$LAST_HOTFIX_DONE" | md5sum | cut -d' ' -f1)"   # private state dir (was predictable /tmp)

if [ ! -f "$ACTION_FLAG" ]; then
  touch "$ACTION_FLAG"
  # Emit decision:block + directive so the agent acts
  jq -n --arg hrs "$HOURS_SINCE" '{
    systemMessage: (" Hotfix postmortem pending: /hotfix completed \($hrs)h ago without an incident post-mortem."),
    hookSpecificOutput: {
      decision: "block",
      reason: ("HOTFIX FOLLOWUP (act now, do not just acknowledge): /hotfix completed " + $hrs + "h ago but no post-mortem (/incident-response Phase 3) has run yet. Before closing this session, run /incident-response with Phase 3 to enforce ADR capture, regression test, and memory update.")
    }
  }'
else
  # Already fired in this session; fall back to systemMessage only
  jq -n --arg hrs "$HOURS_SINCE" \
    '{"systemMessage": (" Hotfix postmortem pending: /hotfix completed \($hrs)h ago without an incident post-mortem. /incident-response Phase 3 enforces ADR + regression test + memory capture.")}'
fi

exit 0
