#!/usr/bin/env bash
# context-guard.sh — PostToolUse hook: tool-result firewall + lost-in-the-middle
# audit + static/dynamic cache boundary marker.
#
# The cross-wave research converged hard on one thing: context bloat is the #1
# silent killer of "optimal results on any model." Three concrete defenses come
# out of that:
#
#   1. TOOL-RESULT FIREWALL (contextweaver / agentforge). A raw tool response of
#      N KB gets swapped for a one-line compact summary before it re-enters the
#      model's context. contextweaver reported 92.2% route-prompt reduction with
#      no accuracy loss. We can't edit the tool result in-place from a hook, but
#      we CAN emit a compact digest to a sidecar file the distill/diagnose path
#      reads, and emit a stderr nudge the agent sees when a result is huge.
#
#   2. LOST-IN-THE-MIDDLE AUDIT. Liu et al.: models attend to the START and END
#      of the prompt, not the middle. Constraints buried mid-context get missed.
#      This hook appends a "constraint recap" line to a known file so a
#      PreCompact/session-start reinject can surface constraints at the start of
#      the next window. It is advisory — it does not block.
#
#   3. STATIC/DYNAMIC CACHE BOUNDARY MARKER (agentforge). Prompt caches hit best
#      when stable prefix is separated from volatile suffix. This hook records a
#      boundary marker into the trajectory so the cache boundary is auditable.
#
# This is pure observation + sidecar writes. NEVER blocks a tool call. Exit 0
# always (a context-guard that blocks would be a foot-gun).
#
# Wire in claude/settings.json PostToolUse alongside trajectory-log.sh.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DIGESTS="$RUNTIME/tool-digests"
CONSTRAINTS="$RUNTIME/constraints-recap.md"
BOUNDARY="$RUNTIME/cache-boundary.jsonl"
mkdir -p "$RUNTIME" "$DIGESTS"

read_hook_stdin
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

tool_name="$(hook_field "$HOOK_INPUT" ".tool_name // .tool")"
tool_response="$(hook_field_json "$HOOK_INPUT" ".tool_response // .tool_result // empty" || echo 'null')"

# --- 1. Tool-result firewall ------------------------------------------------
# If the response exceeds the budget, write a compact digest sidecar and emit a
# stderr nudge. The agent never sees the full payload re-enter context via this
# hook — but the distill/diagnose engines read the digest instead of the raw
# response, which is where most re-entry happens in this harness.
BUDGET=2048
resp_len="$(printf '%s' "$tool_response" | wc -c | tr -d ' ')"
if [[ "$resp_len" -gt "$BUDGET" ]]; then
  # One-line digest: first 160 chars of meaningful content, stripped of noise.
  digest="$(printf '%s' "$tool_response" \
    | tr '\n' ' ' \
    | sed -E 's/\s+/ /g' \
    | head -c 160)"
  safe_tool="$(printf '%s' "$tool_name" | tr -c '[:alnum:]-' '_')"
  : > "$DIGESTS/${ts//[:]/-}_${safe_tool}.digest"
  printf '%s\n' "$digest" >> "$DIGESTS/${ts//[:]/-}_${safe_tool}.digest"
  # Non-blocking nudge the agent sees in hook stderr.
  printf 'context-guard: %s response was %s bytes (>%s); compact digest written to tool-digests/ — prefer reading the digest.\n' \
    "$tool_name" "$resp_len" "$BUDGET" >&2
fi

# --- 2. Lost-in-the-middle audit -------------------------------------------
# Detect constraint-shaped strings ("MUST", "NEVER", "ALWAYS", "DO NOT") in the
# tool response and append them to a recap file that the reinject-on-compact
# path surfaces at the START of the next window (where attention is strongest).
if printf '%s' "$tool_response" | rg -qi 'MUST|NEVER|ALWAYS|DO NOT|REQUIRED|FORBIDDEN'; then
  printf '## %s — %s\n' "$tool_name" "$ts" >> "$CONSTRAINTS"
  printf '%s\n' "$tool_response" | rg -i 'MUST|NEVER|ALWAYS|DO NOT|REQUIRED|FORBIDDEN' \
    | head -5 >> "$CONSTRAINTS"
  printf '\n' >> "$CONSTRAINTS"
fi

# --- 3. Static/dynamic cache boundary marker --------------------------------
# Record a boundary event so the cache boundary is auditable. "static" = prompt
# prefix that should be cache-stable; "dynamic" = per-call volatile suffix.
boundary="dynamic"
if printf '%s' "$tool_name" | rg -qi 'Read|read_files|Glob|Grep|rg'; then
  boundary="static"   # read-only lookups are cache-stable input
fi
printf '{"ts":"%s","event":"cache-boundary","tool":"%s","boundary":"%s","resp_len":%s}\n' \
  "$ts" "$tool_name" "$boundary" "$resp_len" >> "$BOUNDARY"

exit 0
