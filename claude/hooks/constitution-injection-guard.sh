#!/usr/bin/env bash
# constitution-injection-guard.sh — UserPromptSubmit hook: predictive constitution
# injection.
#
# Gap: every PreToolUse gate in this repo (bash-safety, dangerous-pattern,
# push-to-main, policy-gate) fires AFTER the model has already decided to call
# a risky tool — it blocks the action, not the intent forming. A real-world
# report (r/ClaudeAI, 2026-08) showed a documented "please stop" rule getting
# technically satisfied while its intent was violated (serialized instead of
# stopped, kept running): "Rules failed three times. Injections haven't been
# beaten once." The fix there was pattern-matching the PROMPT and pre-loading
# the binding constraint into context before the model starts reasoning, not
# just gating the tool call after the fact.
#
# This hook is that missing layer for THIS repo's own constitution
# (.harness/constitution.json): pattern-match the incoming prompt for risk
# categories that map to a Protected Invariant or Escalate-When condition, and
# inject the relevant clause as additionalContext before the model plans any
# tool call. It never blocks (exit 0 always) — PreToolUse gates remain the
# enforcement backstop; this only shapes what the model has in context going
# in, the same mechanism mode-reminder.sh already uses for caveman/ponytail.
#
# Bash-3.2-safe: parallel indexed arrays, not `declare -A` (this hook is
# invoked as a literal `bash script.sh` by the host, which resolves whatever
# /bin/bash is first on PATH — stock macOS bash 3.2 on unconfigured machines).
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0   # no jq -> degrade silently, never block the prompt

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -n "$PROMPT" ] || exit 0

LP=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Parallel arrays: category -> pattern -> constitution clause to inject.
# Patterns are extended regex (grep -E), matched case-insensitively against
# the lowercased prompt. Keep patterns specific enough to avoid noise on
# every turn — this only fires when the prompt actually smells like it's
# heading into one of these categories.
CATEGORIES=(irreversible production-impacting security-sensitive self-mod-human-review pr-automation-halt)
PATTERNS=(
  "rm -rf|force.push|force-push|reset --hard|drop table|drop database|truncate|wipe|purge|discard.*(changes|commits)|delete.*(branch|history)"
  "production|\bprod\b|deploy|release to (users|customers)|live system|ship to (main|master)"
  "\.env\b|api.?key|credential|password|secret|token|private key|\.pem\b|auth(entication)?.*(bypass|disable)"
  "hooks/|claude/skills/|claude/settings\.json|\.harness/.*polic|self.mod|modify.*(hook|settings)"
  "merge (this|that|the) pr|approve (this|that|the) pr|someone else.s pr|another person.s pr"
)
MESSAGES=(
  "Escalate-when: irreversible. Destructive operations that cannot be undone (data deletion, force-push, schema drops) require stopping and asking the human before proceeding (.harness/constitution.md)."
  "Escalate-when: production-impacting. Changes that affect live systems or user-facing behavior require stopping and asking the human before proceeding (.harness/constitution.md)."
  "Escalate-when: security-sensitive. Changes touching auth, secrets, credentials, or infra permissions require stopping and asking the human before proceeding (.harness/constitution.md)."
  "Protected invariant: self-mod-human-review. No change to hooks/, claude/skills/, claude/settings.json, .claude/settings.json, or .harness/ policy files may be applied to a live path or merged without explicit human approval (.harness/constitution.md)."
  "Protected invariant: pr-automation-halt. Never automate any action on a PR with comments from another person, or any open PR authored by another person. Bots don't count (.harness/constitution.md)."
)

matched=()
i=0
while [ "$i" -lt "${#CATEGORIES[@]}" ]; do
  if printf '%s' "$LP" | grep -Eq "${PATTERNS[$i]}"; then
    matched+=("${MESSAGES[$i]}")
  fi
  i=$((i + 1))
done

[ "${#matched[@]}" -eq 0 ] && exit 0

# Bounded: cap at 2 clauses so a prompt matching multiple categories doesn't
# dump the whole constitution into context.
D="${matched[0]}"
[ "${#matched[@]}" -gt 1 ] && D="$D ${matched[1]}"

jq -n --arg d "$D" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$d}}'
exit 0
