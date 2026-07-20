#!/usr/bin/env bash
# UserPromptSubmit hook — enforce CLAUDE.md "Ponytail mode ALWAYS ON (full) by default".
# Injects the ponytail directive into context every turn so the rule actually fires
# (memory/preferences can't; only a hook can — the harness runs this, not Claude).
#
# Toggle (session-scoped, per ponytail's own stated boundary):
#   "stop ponytail" / "normal mode"        -> off for THIS session (session-scoped sentinel)
#   "ponytail on" / "start ponytail" / "/ponytail" -> back on
# Sentinel is keyed by session_id, so a new session has no sentinel -> defaults ON (full).
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # no jq -> degrade silently, never block the prompt

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null || echo nosession)
SENTINEL="${TMPDIR:-/tmp}/.ponytail-off-${SID}"

LP=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

case "$LP" in
  *"stop ponytail"*|*"normal mode"*)
    : > "$SENTINEL"
    jq -n '{"systemMessage":"Ponytail mode OFF for this session. (Defaults back ON — full — next session.)"}'
    exit 0 ;;
  *"ponytail on"*|*"start ponytail"*|*"/ponytail"*)
    rm -f "$SENTINEL" ;;
esac

[ -f "$SENTINEL" ] && exit 0

DIRECTIVE="PONYTAIL MODE ACTIVE — level: full (default-on per CLAUDE.md). Lazy senior dev: before writing code, climb the ladder and stop at the first rung that holds — (1) does this need to exist at all (YAGNI, skip speculative need), (2) already in this codebase (reuse, don't reimplement), (3) stdlib does it, (4) native platform feature covers it, (5) already-installed dependency solves it, (6) can it be one line, (7) only then the minimum code that works. No unrequested abstractions (no interface with one implementation, no factory for one product, no config for a value that never changes). Deletion over addition, boring over clever. Bug fix = root cause in the shared function, not a per-caller patch. Mark deliberate shortcuts with a 'ponytail:' comment naming the ceiling and upgrade trigger. Non-trivial logic (branch/loop/parser/money/security path) leaves one runnable check behind. Never simplify away input validation at trust boundaries, error handling that prevents data loss, security measures, or anything explicitly requested. Output: code first, then at most three short lines on what was skipped and when to add it — skip this footer entirely when the user asked for full explanatory output (a report, walkthrough, or phase notes). Turn off this session only if the user says 'stop ponytail' or 'normal mode'."

jq -n --arg d "$DIRECTIVE" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$d}}'
exit 0
