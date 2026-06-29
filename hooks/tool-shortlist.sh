#!/usr/bin/env bash
# tool-shortlist.sh — PreToolUse hook: bounded tool shortlist / deferred ToolSearch.
#
# The cross-wave research flagged context bloat as the #1 silent killer of
# "optimal results on any model." Two concrete patterns address system-prompt
# bloat from a large tool catalog:
#
#   - BOUNDED TOOL SHORTLIST / ChoiceCards (contextweaver): instead of loading
#     the full toolset into the system prompt, suggest only the tools relevant
#     to the current task. contextweaver reported 92.2% route-prompt reduction
#     with no accuracy loss. Pattern #12.
#   - DEFERRED TOOLS via ToolSearch (agentforge, Copilot): tools are loaded on
#     demand via a search call, cutting the system prompt 60-70%. Pattern #10.
#
# This hook can't edit the system prompt in-place, but it CAN emit a shortlist
# advisory to a sidecar + a stderr nudge so the host agent knows which tools are
# relevant to the current input. It also records the tool-catalog-context signal
# to the trajectory so the distill/diagnose engines can detect tool-catalog bloat.
#
# This is advisory — it never blocks (exit 0 always). It fires on UserPromptSubmit
# (via the UserPromptSubmit event) to suggest a shortlist BEFORE the agent picks
# tools, and on PreToolUse to record what was actually used.
#
# Usage (as a hook — reads stdin JSON):
#   UserPromptSubmit:  hooks/tool-shortlist.sh   (suggests relevant tools)
#   PreToolUse:        hooks/tool-shortlist.sh   (records tool-catalog usage)
#
# Usage (CLI):
#   hooks/tool-shortlist.sh suggest "<prompt>"   # print a bounded shortlist
#   hooks/tool-shortlist.sh --status             # print last shortlist stats
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
SHORTLISTS="$RUNTIME/tool-shortlists.jsonl"
mkdir -p "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Tool catalog with keywords (bounded, cache-stable) --------------------
# Each entry: tool name + the keywords that signal relevance. This is the
# "shortlist source" — the full catalog lives here, but only matching entries
# are surfaced to the agent, keeping the active context bounded.
declare -A TOOL_KEYWORDS
TOOL_KEYWORDS[Read]="read file contents view source"
TOOL_KEYWORDS[Write]="write create file contents new"
TOOL_KEYWORDS[Bash]="bash shell command run execute terminal"
TOOL_KEYWORDS[Grep]="search find grep regex symbol"
TOOL_KEYWORDS[Glob]="glob find files pattern match"
TOOL_KEYWORDS[Edit]="edit modify replace patch diff"
TOOL_KEYWORDS[WebSearch]="search web internet query"
TOOL_KEYWORDS[WebFetch]="fetch url web page http"
TOOL_KEYWORDS[TodoWrite]="todo task list track manage"
TOOL_KEYWORDS[Task]="subagent spawn delegate parallel"
TOOL_KEYWORDS[MCP]="mcp server external tool resource"

# --- CLI mode: suggest -------------------------------------------------------
if [[ "${1:-}" == "suggest" ]]; then
  prompt="${2:-}"
  [[ -n "$prompt" ]] || { echo "tool-shortlist: suggest requires a <prompt>" >&2; exit 2; }
  echo "# Tool shortlist for: $prompt"
  echo "# (bounded — only tools whose keywords match the prompt are surfaced)"
  echo
  matched=0
  for tool in "${!TOOL_KEYWORDS[@]}"; do
    kws="${TOOL_KEYWORDS[$tool]}"
    # Lowercase match on any keyword.
    if printf '%s' "$prompt" | grep -Eqi "$(printf '%s' "$kws" | tr ' ' '|')"; then
      printf -- "- %s (keywords: %s)\n" "$tool" "$kws"
      matched=$((matched + 1))
    fi
  done
  [[ "$matched" -eq 0 ]] && echo "- (no keyword match; consider the full catalog)"
  # Record the shortlist event.
  printf '{"ts":"%s","event":"tool-shortlist","prompt_preview":"%s","matched":%s}\n' \
    "$ts" "$(printf '%s' "$prompt" | head -c 80 | tr '\n' ' ')" "$matched" >> "$SHORTLISTS"
  exit 0
fi

if [[ "${1:-}" == "--status" ]]; then
  [[ -f "$SHORTLISTS" ]] || { echo "no shortlist events yet"; exit 0; }
  echo "shortlist events: $(wc -l < "$SHORTLISTS" | tr -d ' ')"
  echo "avg matched tools: $(jq -s 'map(.matched) | add / length' "$SHORTLISTS" 2>/dev/null || echo "?")"
  exit 0
fi

# --- Hook mode: read stdin JSON ----------------------------------------------
input="$(cat)"
prompt_text="$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // .tool_input.prompt // empty' 2>/dev/null || true)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null || true)"

# On UserPromptSubmit: suggest a shortlist if we have prompt text.
if [[ -n "$prompt_text" ]]; then
  # Emit shortlist to a sidecar the host agent can read.
  sidecar="$RUNTIME/shortlist-${ts//[:]/-}.md"
  {
    printf '# Suggested tool shortlist — %s\n\n' "$ts"
    printf 'Only the tools whose keywords match your prompt are listed. Using this\n'
    printf 'bounded set instead of the full catalog reduces system-prompt context\n'
    printf '(contextweaver 92.2%% route-prompt reduction pattern).\n\n'
    matched=0
    for tool in "${!TOOL_KEYWORDS[@]}"; do
      kws="${TOOL_KEYWORDS[$tool]}"
      if printf '%s' "$prompt_text" | grep -Eqi "$(printf '%s' "$kws" | tr ' ' '|')"; then
        printf -- '- %s\n' "$tool"
        matched=$((matched + 1))
      fi
    done
    [[ "$matched" -eq 0 ]] && printf -- '- (no keyword match; use full catalog)\n'
  } > "$sidecar"
  printf 'tool-shortlist: %s tools matched; shortlist at %s\n' "$matched" "$sidecar" >&2
  printf '{"ts":"%s","event":"tool-shortlist","matched":%s,"sidecar":"%s"}\n' \
    "$ts" "$matched" "$sidecar" >> "$SHORTLISTS"
fi

# On PreToolUse: record which tool was actually used (for catalog-bloat detection).
if [[ -n "$tool_name" ]]; then
  printf '{"ts":"%s","event":"tool-used","tool":"%s"}\n' "$ts" "$tool_name" >> "$SHORTLISTS"
fi

exit 0
