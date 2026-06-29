#!/usr/bin/env bash
# check-read-only-subagent.sh — SubagentStart hook.
# Enforces the RULES.md "Read-only-by-construction" + "Independence gate"
# invariants. A subagent dispatched for analysis (review, explore, plan, audit,
# critic, security) MUST deny write/edit tools in its permission block — not
# merely a prompt instruction. This hook inspects the subagent spawn payload and
# blocks (exit 2) if an analysis-role subagent is spawned with write capability.
#
# Independence gate: review/security/critic agents must be independent
# subagents, never collapsed into the implementer lane. We cannot enforce lane
# separation from inside a single hook, but we can refuse to spawn an analysis
# subagent that carries write tools — which is the structural precondition for
# independence.
set -uo pipefail

input="$(cat)"

# SubagentStart payload varies by host; try common shapes.
name="$(printf '%s' "$input" | jq -r '.subagent_name // .name // .agent // .subagent.type // empty' 2>/dev/null || true)"
prompt="$(printf '%s' "$input" | jq -r '.subagent_prompt // .prompt // .description // empty' 2>/dev/null || true)"
perms="$(printf '%s' "$input" | jq -r '.subagent_permissions // .permissions // .allowed_tools // empty' 2>/dev/null || true)"

# Classify role by name/prompt keywords.
is_analysis=0
combined="$name $prompt"
case "$(printf '%s' "$combined" | tr '[:upper:]' '[:lower:]')" in
  *review*|*audit*|*explore*|*plan*|*critic*|*security*|*analysis*|*investigate*|*inspect*)
    is_analysis=1 ;;
esac
[[ "$is_analysis" -eq 1 ]] || exit 0

# Detect write-capable tools in the permission block. Hosts express this
# differently; match common forms.
write_tools_pattern='(Write|Edit|MultiEdit|Bash|Shell|Execute|NotebookEdit|create_file|edit_file|write_file)'
if printf '%s' "$perms" | grep -Eq "$write_tools_pattern"; then
  echo "BLOCKED — read-only-by-construction violation (RULES.md):" >&2
  echo "  subagent: $name" >&2
  echo "  role:     analysis (review/explore/plan/audit/critic/security)" >&2
  echo "  reason:   analysis subagents must deny Write/Edit/Bash in their permission block, not just the prompt." >&2
  echo "  fix:      strip write tools from the subagent permission block; the orchestrator or a separate implementer stage applies edits." >&2
  exit 2
fi

# If no explicit permission block was supplied, emit a hint but do not block —
# many hosts default to inherit, which we cannot introspect from here.
echo "HINT: analysis subagent '$name' spawned without an explicit read-only permission block (RULES.md read-only-by-construction). Verify write tools are denied in its permission block." >&2
exit 0
