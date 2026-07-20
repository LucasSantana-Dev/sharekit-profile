#!/usr/bin/env bash
# complexity-classifier.sh — UserPromptSubmit hook
# Zero-cost prompt complexity classifier. Pure bash heuristics, no external API calls.
#
# Outputs JSON { "systemMessage": "..." } with:
#   - Complexity level (low/medium/high/critical)
#   - Recommended model for Agent tool calls
#   - Smart /command suggestions for Claude to act on
#
# Cost: $0. Timeout: 3s.

set -uo pipefail

PROMPT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message') or d.get('prompt') or ''
    if isinstance(msg, list):
        msg = ' '.join(p.get('text','') for p in msg if isinstance(p, dict))
    print(str(msg)[:2000])
except Exception:
    print('')
" 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')
prompt_lower=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# ── Signal patterns ──────────────────────────────────────────────────────────

# CRITICAL: security, auth, architecture, production incidents, rollbacks, secret rotation
CRITICAL="(secur|vulnerab|cve|exploit|oauth|encrypt|auth middleware|deploy to prod|production deploy|incident|postmortem|data loss|data breach|architect|overhaul|redesign|refactor entire|database migration|migrate .* database|rollback|hotfix|hot fix|on-call|oncall|rce|remote code exec|secret rotation|rotate .* secret|injection attack|data loss prevention)"

# HIGH: substantial implementation, skill invocations, multi-file work, debugging, PR work
HIGH="(implement|build .* feature|create .* system|add .* feature|fix .* bug|debug|write tests? for|refactor|optimize performance|integrate|configure .* service|pr review|code review|pull request|write a pr|open a pr|create a pr|create an issue|write a ticket|performance issue|memory leak|race condition|schema design|api design|/plan|/ship|/loop|/deploy|/orchestrate|/add |audit|walk me through|explain the entire|explain all|summarize all|how does .* work in detail)"

# LOW: short search/lookup/navigation — anchors removed; WORD_COUNT gate is the guard
LOW="(find |show me|list |grep |search for|check |what is |where is |which |how many |does .* exist|git log|git status|git diff|git show|npm list|read file|look at|tldr|tl;dr|translate)"

# ── Classify ─────────────────────────────────────────────────────────────────

# Persist task level across continuations
COMPLEXITY_FILE="$HOME/.claude/.task-complexity"
persisted_level=""
[[ -f "$COMPLEXITY_FILE" ]] && persisted_level=$(cat "$COMPLEXITY_FILE" 2>/dev/null || echo "")

# Continuation phrases — short follow-ups that should inherit the ongoing task level
CONTINUATION="^(continue|go ahead|yes|ok|okay|proceed|next|keep going|do it|sounds good|what else|anything else|let'?s do it|sure|yep|yup|great|perfect|good|correct|right|exactly|that'?s right|alright|confirmed|done|looks good|ship it|lgtm|merge it|go for it|fix it|try again|retry|run it|run tests|check it|verify|test it|deploy it|push it)$"

LEVEL="medium"
# Short continuation inherits persisted task level when work is already in flight
if [[ -n "$persisted_level" && "$persisted_level" != "medium" && "$persisted_level" != "low" ]] &&
	[ "$WORD_COUNT" -lt 8 ] &&
	echo "$prompt_lower" | grep -qE "$CONTINUATION"; then
	LEVEL="$persisted_level"
	echo "$LEVEL" >"$COMPLEXITY_FILE" 2>/dev/null || true
	exit 0 # Skip injection — model hint already in place from prior turn
fi

if echo "$prompt_lower" | grep -qE "$CRITICAL"; then
	LEVEL="critical"
elif echo "$prompt_lower" | grep -qE "$HIGH"; then
	# HIGH match always wins over word-count-based LOW
	LEVEL="high"
elif [ "$WORD_COUNT" -lt 20 ] && echo "$prompt_lower" | grep -qE "$LOW"; then
	LEVEL="low"
elif [ "$WORD_COUNT" -lt 4 ] && ! echo "$prompt_lower" | grep -qE "$HIGH"; then
	LEVEL="low"
fi

# Write for statusline
echo "$LEVEL" >"$HOME/.claude/.task-complexity" 2>/dev/null || true

# ── Model + command map ───────────────────────────────────────────────────────

case "$LEVEL" in
low)
	MSG=$(
		cat <<'MSG'
[AUTO] LOW complexity. Keep response concise.
- Agent tool calls: pass model="haiku"
- Skip extended reasoning
- One-paragraph max unless detail is explicitly requested
MSG
	)
	;;
medium)
	MSG=$(
		cat <<'MSG'
[AUTO] MEDIUM complexity.
- Agent tool calls: model="haiku" for search/lookup, model="sonnet" for multi-file edits or analysis
MSG
	)
	;;
high)
	MSG=$(
		cat <<'MSG'
[AUTO] HIGH complexity. Be thorough.
- Agent tool calls: pass model="sonnet"
- Use /think if this involves a tricky debugging step or design decision
- Verify your reasoning before committing to a solution
MSG
	)
	;;
critical)
	MSG=$(
		cat <<'MSG'
[AUTO] CRITICAL complexity detected (security / architecture / production / migration).
- Use /think before making consequential decisions
- Agent tool calls: pass model="fable" (falls back to model="opus" if Fable unavailable/degraded) — per ADR-0049
- Consider /model fable for this session if doing sustained security or architecture work
- Flag any irreversible actions before executing them
- Verify assumptions against actual code, not memory
MSG
	)
	;;
esac

python3 -c "
import json, sys
msg = sys.stdin.read().strip()
print(json.dumps({'systemMessage': msg}))
" <<MSGEOF
$MSG
MSGEOF
