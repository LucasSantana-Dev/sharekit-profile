#!/usr/bin/env bash
# check-dangerous-patterns.sh — PreToolUse hook.
# Reads .harness/mcp-policy.json, regex-matches the incoming Bash command
# against each dangerousPattern, and exits 2 (block) on any match.
# Non-Bash tools and missing policy files are allowed (exit 0).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared/common.sh"

POLICY="$ROOT/.harness/mcp-policy.json"
SENSITIVE_PATHS="$ROOT/.harness/sensitive-paths.json"

if [[ ! -f "$POLICY" ]]; then
  echo "WARN: .harness/mcp-policy.json not found — dangerous-pattern hook disabled (fail-open)" >&2
  exit 0
fi

# Read the tool invocation JSON from stdin.
read_hook_stdin

# Only govern Bash. Allow everything else.
tool_name="$(hook_field "$HOOK_INPUT" ".tool_name")"
if [[ -n "$tool_name" && "$tool_name" != "Bash" && "$tool_name" != "bash" ]]; then
  exit 0
fi

# Extract the command field. Claude Code PreToolUse sends {tool_name, tool_input:{command}}.
command="$(hook_field "$HOOK_INPUT" ".tool_input.command // .command")"

if [[ -z "$command" ]]; then
  # Not a Bash invocation we can inspect — allow.
  exit 0
fi

# Walk the dangerousPatterns array and regex-match.
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  if printf '%s' "$command" | rg -q "$pattern"; then
    echo "BLOCKED by .harness/mcp-policy.json dangerousPattern:" >&2
    echo "  pattern:  $pattern" >&2
    echo "  command:  $command" >&2
    echo "Override by editing .harness/mcp-policy.json and regenerating fingerprints." >&2
    exit 2
  fi
done < <(jq -r '.dangerousPatterns[]?' "$POLICY")

# Check file paths against sensitive-paths deny-list (non-overridable, checked FIRST).
if [[ -f "$SENSITIVE_PATHS" ]]; then
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    # Convert glob pattern to regex: * → [^/]*, ** → .*, ? → [^/]
    regex="$(printf '%s' "$pattern" | sed 's|\*\*|__DS__|g; s|\*|[^/]*|g; s|?|[^/]|g; s|__DS__|.*|g')"
    if printf '%s' "$command" | rg -q "$regex"; then
      echo "BLOCKED by .harness/sensitive-paths.json (non-overridable):" >&2
      echo "  pattern:  $pattern" >&2
      echo "  command:  $command" >&2
      exit 2
    fi
  done < <(jq -r '.paths[]?' "$SENSITIVE_PATHS" 2>/dev/null || jq -r '.[]?' "$SENSITIVE_PATHS" 2>/dev/null)
fi

exit 0
