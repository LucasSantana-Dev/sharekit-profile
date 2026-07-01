#!/usr/bin/env bash
# check-idempotency.sh — PreToolUse hook.
# Enforces the "state-check before mutation" RULES.md invariant.
# A write/edit/push/upsert that does not first query current state is a contract
# violation. This hook is advisory-on-first-offense: it logs the unverified
# mutation to the trajectory log and emits a stderr hint. It does NOT block
# (exit 0) because legitimate one-shot edits exist; the trajectory record lets
# the nightly distill surface repeat offenders.
#
# Rationale: hard-blocking here would break too many valid flows, but a silent
# advisory rule is enforceable only if every violation is observable. Logging
# is the enforcement mechanism — the eval gate reads this log.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/.harness/runtime/idempotency.jsonl"
mkdir -p "$(dirname "$LOG")"

input="$(sed -n '1,$p')"

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"

# Only govern mutating tools.
case "$tool_name" in
  Write|Edit|MultiEdit|Bash) ;;
  *) exit 0 ;;
esac

# For Bash, only flag commands that mutate external state.
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
if [[ "$tool_name" == "Bash" ]]; then
  # Mutating command signatures we care about.
  if ! printf '%s' "$command" | rg -q '\b(git\s+push|git\s+commit|npm\s+publish|kubectl\s+apply|terraform\s+apply|curl\s+.*(POST|PUT|DELETE)|DELETE\s+FROM|UPDATE\s+.*SET)\b'; then
    exit 0
  fi
fi

# We cannot introspect prior tool calls from inside a single hook invocation
# (Claude Code hooks are stateless per-call), so we record the mutation and
# let the distill pass detect missing state-checks by pairing against the
# trajectory log. Emit the hint so the agent self-corrects in-session.
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -nc \
  --arg ts "$ts" \
  --arg tool "$tool_name" \
  --arg cmd "$command" \
  '{ts: $ts, event: "unverified-mutation", tool: $tool, command: $cmd}' \
  >> "$LOG"

echo "HINT: state-check before mutation — verify current state before this write/push/upsert (RULES.md idempotency). Logged to trajectory." >&2
exit 0
