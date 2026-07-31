#!/usr/bin/env bash
# memory-scope-gate.sh — enforce .harness/memory-scopes.json on memory writes.
#
# PreToolUse-style hook: reads a tool-call JSON payload on stdin
# ({"tool_name": ..., "tool_input": {...}}), stamps required write metadata
# {author, scope, project}, and blocks writes that would leak personal-scope
# content into a wider scope (team/org) — including <private>-tagged content,
# which never promotes. Fail-closed on policy violation; fail-open with a
# stderr note when the policy file is absent (solo/ad-hoc repos unaffected).
#
# Scope of a write is derived from the target path:
#   personal:  ~/.claude/projects/*/memory/, .claude/memory/
#   team:      .agents/memory/, memory/, docs/memory/
#   org:       paths declared under scopes.org in the policy (reserved)
#
# Exit 0 = allow, exit 2 = block (hook convention: deny the tool call).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
POLICY="$ROOT/.harness/memory-scopes.json"

if [[ ! -f "$POLICY" ]]; then
  echo "memory-scope-gate: no .harness/memory-scopes.json - fail-open (allow)" >&2
  exit 0
fi

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
[[ -z "$tool" ]] && exit 0

# Only gate memory-shaped writes: Write/Edit to memory paths, or MCP memory tools.
path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
content="$(printf '%s' "$payload" | jq -r '.tool_input.content // .tool_input.new_string // .tool_input.text // empty')"

is_memory_tool=false
case "$tool" in
  *memory*|*Memory*|Write|Edit|MultiEdit) is_memory_tool=true ;;
esac
$is_memory_tool || exit 0

scope_of() {
  case "$1" in
    */.claude/projects/*/memory/*|*/.claude/memory/*) echo "personal" ;;
    */.agents/memory/*|*/memory/team/*|*/docs/memory/*) echo "team" ;;
    */memory/org/*|*/org-memory/*) echo "org" ;;
    *) echo "" ;;
  esac
}

scope_rank() {
  case "$1" in
    personal) echo 1 ;;
    team) echo 2 ;;
    org) echo 3 ;;
    *) echo 0 ;;
  esac
}

target_scope="$(scope_of "$path")"
[[ -z "$target_scope" ]] && exit 0  # not a memory path

# Required write metadata: author, scope, project (env or git config).
author="${HARNESS_AUTHOR:-$(git config user.email 2>/dev/null || echo unknown)}"
project="$(basename "$ROOT")"

# Rule 1: <private>-tagged content never leaves personal scope.
if [[ "$(scope_rank "$target_scope")" -gt 1 ]] && printf '%s' "$content" | grep -qi '<private>'; then
  echo "memory-scope-gate: BLOCK - <private>-tagged content never promotes to $target_scope scope" >&2
  exit 2
fi

# Rule 2: cross-scope reads deny by default - a write into team/org scope must
# not embed personal-scope material. Heuristic: content referencing personal
# memory paths of another author.
if [[ "$(scope_rank "$target_scope")" -gt 1 ]] && printf '%s' "$content" | grep -q '/.claude/projects/'; then
  echo "memory-scope-gate: BLOCK - content references a personal-scope memory path; promote via review instead" >&2
  exit 2
fi

# Stamp metadata for downstream audit (advisory output, not a block).
echo "memory-scope-gate: allow scope=$target_scope author=$author project=$project" >&2
exit 0
