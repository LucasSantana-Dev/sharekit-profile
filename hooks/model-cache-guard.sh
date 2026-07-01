#!/usr/bin/env bash
# model-cache-guard.sh — cache-aware model routing guidance (Pattern #11).
#
# Cross-wave research (Copilot, agentcache) converged on one cache discipline:
# prompt caches are invalidated the moment the system-prompt prefix changes.
# The two cache-safe model-switch boundaries are:
#
#   1. FIRST TURN — the conversation has no cached prefix yet, so the first
#      model choice is free (no cache to lose).
#   2. POST-COMPACTION — a compact event resets the working context, so a
#      model switch here loses nothing (the prefix was going to be rebuilt
#      anyway).
#
# Any model switch at any other point is CACHE-UNSAFE: it discards the cached
# prefix the prior model built up, forcing a full re-cache. This is the single
# biggest silent latency/cost tax on long conversations.
#
# This hook can't see the model directly (it's not in the hook payload for
# most harnesses), so it works by tracking a session-level model signature
# derived from the hook event stream + the settings it CAN see. When a switch
# is detected mid-session (not first-turn, not post-compaction), it emits an
# advisory stderr nudge + records the event for the distill/diagnose engines.
#
# This is advisory — it NEVER blocks (exit 0 always). A model switch is the
# host's call; this hook just makes the cache cost visible.
#
# Wire in claude/settings.json on UserPromptSubmit (to track turn count and
# detect switches) and on PostCompact (to mark the next turn as cache-safe).
#
# Usage (as a hook — reads stdin JSON):
#   UserPromptSubmit:  hooks/model-cache-guard.sh          (detect mid-turn switches)
#   PostCompact:       OBSERVE_HOOK_EVENT=PostCompact hooks/model-cache-guard.sh
#                     (mark next turn as cache-safe boundary)
#
# Usage (CLI):
#   hooks/model-cache-guard.sh --status     # print switch stats
#   hooks/model-cache-guard.sh --reset      # reset session tracker (new session)
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared/common.sh"

SESSIONS="$RUNTIME/model-session.jsonl"
SWITCHES="$RUNTIME/model-switches.jsonl"
mkdir -p "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- CLI modes ---------------------------------------------------------------
if [[ "${1:-}" == "--status" ]]; then
  [[ -f "$SWITCHES" ]] || { echo "no model-switch events recorded"; exit 0; }
  total="$(wc -l < "$SWITCHES" | tr -d ' ')"
  unsafe="$(jq -c 'select(.safe==false)' "$SWITCHES" 2>/dev/null | rg -c '.' || echo 0)"
  safe="$(jq -c 'select(.safe==true)' "$SWITCHES" 2>/dev/null | rg -c '.' || echo 0)"
  echo "model-switch events: $total"
  echo "  cache-safe (first-turn/post-compact): $safe"
  echo "  cache-unsafe (mid-conversation): $unsafe"
  if [[ "$unsafe" -gt 0 ]]; then
    echo ""
    echo "recent cache-unsafe switches:"
    jq -r 'select(.safe==false) | "  \(.ts) turn=\(.turn // \"?\") reason=\(.reason // \"?\")"' "$SWITCHES" 2>/dev/null | tail -5
  fi
  exit 0
fi

if [[ "${1:-}" == "--reset" ]]; then
  : > "$SESSIONS" 2>/dev/null || true
  echo "model-cache-guard: session tracker reset"
  exit 0
fi

# --- Hook mode ---------------------------------------------------------------
read_hook_stdin

# Extract any model identifier we can see. Different harnesses expose it under
# different keys; try the common ones.
model_sig="$(printf '%s' "$HOOK_INPUT" | jq -r '
  .model
  // .model_id
  // .session.model
  // .tool_input.model
  // .metadata.model
  // empty' 2>/dev/null || true)"

# If we can't see a model signature, we can't detect switches — exit quietly.
[[ -n "$model_sig" ]] || exit 0

# Is this a PostCompact event? If so, mark the next turn as a cache-safe boundary.
if [[ "${OBSERVE_HOOK_EVENT:-}" == "PostCompact" ]]; then
  printf '{"ts":"%s","event":"compact-boundary","model":"%s"}\n' "$ts" "$model_sig" >> "$SESSIONS"
  exit 0
fi

# --- Detect the turn number + last-seen model -------------------------------
# Turn count = number of UserPromptSubmit events we've recorded for this session.
# (PostCompact boundaries reset the "cache-safe window" but don't increment turns.)
turn=0
last_model=""
last_event_was_compact=0
if [[ -f "$SESSIONS" ]]; then
  turn="$(jq -r 'select(.event=="user-turn")' "$SESSIONS" 2>/dev/null | wc -l | tr -d ' ')"
  last_model="$(jq -r 'select(.event=="user-turn") | .model' "$SESSIONS" 2>/dev/null | tail -1)"
  # Check if the most recent event in the session log was a compact-boundary.
  # If so, this turn is immediately post-compaction — a cache-safe switch point.
  last_event_type="$(jq -r '.event' "$SESSIONS" 2>/dev/null | tail -1)"
  [[ "$last_event_type" == "compact-boundary" ]] && last_event_was_compact=1
fi
turn=$((turn + 1))

# Record this turn.
printf '{"ts":"%s","event":"user-turn","turn":%s,"model":"%s"}\n' \
  "$ts" "$turn" "$model_sig" >> "$SESSIONS"

# --- Switch detection --------------------------------------------------------
# A switch is detected when the model signature changes from the last turn.
if [[ -n "$last_model" && "$last_model" != "$model_sig" ]]; then
  # Is this switch cache-safe? Safe = first turn (turn==1) OR just after a compact.
  safe=false
  reason="mid-conversation"
  if [[ "$turn" -eq 1 ]]; then
    safe=true
    reason="first-turn"
  elif [[ "$last_event_was_compact" -eq 1 ]]; then
    safe=true
    reason="post-compaction"
  fi

  printf '{"ts":"%s","event":"model-switch","turn":%s,"from":"%s","to":"%s","safe":%s,"reason":"%s"}\n' \
    "$ts" "$turn" "$last_model" "$model_sig" "$safe" "$reason" >> "$SWITCHES"

  if [[ "$safe" == "false" ]]; then
    # Advisory nudge — the host agent sees this in hook stderr.
    printf 'model-cache-guard: cache-UNSAFE model switch at turn %s (%s → %s). ' \
      "$turn" "$last_model" "$model_sig" >&2
    printf 'Switching mid-conversation discards the cached prompt prefix. ' >&2
    printf 'Prefer switching at first-turn or post-compaction (Pattern #11).\n' >&2
  else
    printf 'model-cache-guard: cache-safe model switch at turn %s (%s → %s, %s).\n' \
      "$turn" "$last_model" "$model_sig" "$reason" >&2
  fi
fi

exit 0
