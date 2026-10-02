#!/usr/bin/env bash
# UserPromptSubmit hook - combined caveman+ponytail reminder (ADR-0050).
# Replaces caveman-mode.sh + ponytail-mode.sh: one ~110-token directive instead of
# ~600 tokens/turn. Full mode definitions: skills/caveman/SKILL.md and ADR-0050; this is
# the per-turn drift anchor. Toggle semantics:
#   "stop caveman" / "stop ponytail"  -> that mode off, THIS session only
#   "normal mode"                     -> both off, this session
#   "caveman on|/caveman" / "ponytail on|/ponytail" -> back on
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # no jq -> degrade silently, never block the prompt

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null || echo nosession)
CAVE_OFF="${TMPDIR:-/tmp}/.caveman-off-${SID}"
PONY_OFF="${TMPDIR:-/tmp}/.ponytail-off-${SID}"
ECON_OFF="${TMPDIR:-/tmp}/.agentecon-off-${SID}"

LP=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

case "$LP" in
  *"normal mode"*)
    : > "$CAVE_OFF"; : > "$PONY_OFF"
    jq -n '{"systemMessage":"Caveman + Ponytail OFF for this session. (Default back ON next session.)"}'
    exit 0 ;;
  *"stop caveman"*)
    : > "$CAVE_OFF"
    jq -n '{"systemMessage":"Caveman OFF for this session."}'
    exit 0 ;;
  *"stop ponytail"*)
    : > "$PONY_OFF"
    jq -n '{"systemMessage":"Ponytail OFF for this session."}'
    exit 0 ;;
esac
case "$LP" in *"caveman on"*|*"start caveman"*|*"/caveman"*) rm -f "$CAVE_OFF" ;; esac
case "$LP" in *"ponytail on"*|*"start ponytail"*|*"/ponytail"*) rm -f "$PONY_OFF" ;; esac
case "$LP" in
  *"stop agent-econ"*|*"stop agent econ"*) : > "$ECON_OFF"; jq -n '{"systemMessage":"Agent-econ reminders OFF for this session."}'; exit 0 ;;
  *"agent-econ on"*|*"agent econ on"*) rm -f "$ECON_OFF" ;;
esac

D=""
[ ! -f "$CAVE_OFF" ] && D="Caveman: terse; code, errors, exact terms verbatim; plain prose for security, destructive, order-sensitive steps."
if [ ! -f "$PONY_OFF" ]; then
  [ -n "$D" ] && D="$D "
  D="${D}Ponytail: YAGNI, reuse, stdlib, minimal code; never trim validation, error handling or security."
fi
if [ ! -f "$ECON_OFF" ]; then
  [ -n "$D" ] && D="$D "
  D="${D}Agent-econ: recall first, grep-first briefs, reports <=200 lines."
fi

[ -z "$D" ] && exit 0
jq -n --arg d "$D" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$d}}'
exit 0
