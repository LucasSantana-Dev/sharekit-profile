#!/usr/bin/env bash
# check-dangerous-patterns.sh — PreToolUse hook.
# Reads .harness/mcp-policy.json, regex-matches the incoming Bash command
# against each dangerousPattern, and exits 2 (block) on any match.
# Non-Bash tools and missing policy files are allowed (exit 0).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/.harness/mcp-policy.json"

if [[ ! -f "$POLICY" ]]; then
  echo "WARN: .harness/mcp-policy.json not found — dangerous-pattern hook disabled (fail-open)" >&2
  exit 0
fi

# Read the tool invocation JSON from stdin.
input="$(cat)"

# Only govern Bash. Allow everything else.
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
if [[ -n "$tool_name" && "$tool_name" != "Bash" && "$tool_name" != "bash" ]]; then
  exit 0
fi

# Extract the command field. Claude Code PreToolUse sends {tool_name, tool_input:{command}}.
command="$(printf '%s' "$input" | jq -r '.tool_input.command // .command // empty' 2>/dev/null || true)"

if [[ -z "$command" ]]; then
  # Not a Bash invocation we can inspect — allow.
  exit 0
fi

# Walk the dangerousPatterns array and regex-match.
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  if printf '%s' "$command" | grep -Eq "$pattern"; then
    echo "BLOCKED by .harness/mcp-policy.json dangerousPattern:" >&2
    echo "  pattern:  $pattern" >&2
    echo "  command:  $command" >&2
    echo "Override by editing .harness/mcp-policy.json and regenerating fingerprints." >&2
    exit 2
  fi
done < <(jq -r '.dangerousPatterns[]?' "$POLICY")

exit 0