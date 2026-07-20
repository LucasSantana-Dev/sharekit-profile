#!/usr/bin/env bash
# UserPromptSubmit hook — enforce CLAUDE.md "Caveman mode ALWAYS ON by default".
# Injects the caveman style directive into context every turn so the rule actually
# fires (memory/preferences can't; only a hook can — the harness runs this, not Claude).
#
# Toggle (per CLAUDE.md "that session only; next session defaults back to ON"):
#   "stop caveman" / "normal mode"      -> off for THIS session (session-scoped sentinel)
#   "caveman on" / "start caveman" / "/caveman" -> back on
# Sentinel is keyed by session_id, so a new session has no sentinel -> defaults ON.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # no jq -> degrade silently, never block the prompt

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null || echo nosession)
SENTINEL="${TMPDIR:-/tmp}/.caveman-off-${SID}"

# lowercased prompt for matching
LP=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

case "$LP" in
  *"stop caveman"*|*"normal mode"*)
    : > "$SENTINEL"
    jq -n '{"systemMessage":"Caveman mode OFF for this session. (Defaults back ON next session.)"}'
    exit 0 ;;
  *"caveman on"*|*"start caveman"*|*"/caveman"*)
    rm -f "$SENTINEL" ;;
esac

# Off this session? stay silent.
[ -f "$SENTINEL" ] && exit 0

DIRECTIVE="CAVEMAN MODE ACTIVE (default-on per CLAUDE.md). Respond terse caveman: drop articles, filler (just/really/basically/actually), pleasantries, hedging. Fragments OK. Short synonyms. Abbreviate common terms (DB/auth/config/fn/impl). Arrows for causality (X -> Y). Keep ALL technical substance, exact terms, code blocks, and quoted errors verbatim. Pattern: [thing] [action] [reason]. [next step]. AUTO-CLARITY EXCEPTION — use normal prose for: security warnings, irreversible/destructive-action confirmations, and multi-step sequences where fragment order risks misread; resume caveman after. Turn off this session only if the user says 'stop caveman' or 'normal mode'."

jq -n --arg d "$DIRECTIVE" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$d}}'
exit 0
