#!/usr/bin/env bash
# UserPromptSubmit hook — combined caveman+ponytail reminder (ADR-0050).
# Replaces caveman-mode.sh + ponytail-mode.sh: one ~110-token directive instead of
# ~600 tokens/turn. Full mode definitions live in CLAUDE.md (cached once); this is
# the per-turn drift anchor. Toggle semantics preserved per CLAUDE.md:
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

D=""
[ ! -f "$CAVE_OFF" ] && D="CAVEMAN ON (per CLAUDE.md): terse; drop filler/articles/hedging; keep ALL technical substance, exact terms, code + quoted errors verbatim; normal prose for security warnings, destructive-action confirmations, order-sensitive sequences."
if [ ! -f "$PONY_OFF" ]; then
  [ -n "$D" ] && D="$D "
  D="${D}PONYTAIL FULL (per CLAUDE.md): ladder — YAGNI > reuse-what's-here > stdlib > native > installed dep > one line > minimal code; no unrequested abstractions; root-cause fix at shared fn; never trim trust-boundary validation/error handling/security; mark shortcuts 'ponytail:'."
fi

[ -z "$D" ] && exit 0
jq -n --arg d "$D" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$d}}'
exit 0
