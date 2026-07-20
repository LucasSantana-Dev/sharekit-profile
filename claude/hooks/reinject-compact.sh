#!/usr/bin/env bash
# reinject-compact.sh — PostCompact hook.
# After compaction, the model's context loses CORE memory and tier-0 facts.
# This hook re-injects the always-true core back into context by writing an
# additional-context block to the session. Cross-wave evidence:
# Wave-3 PreCompact re-injection pattern + lumos L8 memory layer + Totalum.
#
# The re-injected content is the harness's CORE memory file(s). This keeps the
# agent's hard rules, identity, and priorities alive across compaction events,
# which is what makes the harness behave consistently across any model call.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Resolve the memory root. Respect BRAIN_ROOT (megabrain) then the default.
mem_root="${BRAIN_ROOT:-$HOME/.claude/memory}"
core_file=""
for cand in "$mem_root/CORE.md" "$ROOT/claude/memory-structure/examples/CORE.md"; do
  if [[ -f "$cand" ]]; then core_file="$cand"; break; fi
done

# Emit a context-addition payload. Claude Code PostCompact accepts additional
# context via stdout; we wrap the CORE contents in a fenced block.
if [[ -n "$core_file" ]]; then
  printf '# Re-injected CORE memory (PostCompact)\n\n'
  cat "$core_file"
  printf '\n\n---\n^ Re-injected by hooks/reinject-compact.sh. Verify against the source file before acting on any named path/flag.\n'
else
  # No core file found - record the gap so the distill can flag it.
  mkdir -p "$ROOT/.harness/runtime"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"ts":"%s","event":"postcompact-no-core","note":"no CORE.md found for re-injection"}\n' "$ts" \
    >> "$ROOT/.harness/runtime/trajectory.jsonl" 2>/dev/null || true
fi

exit 0
