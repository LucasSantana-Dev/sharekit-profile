#!/usr/bin/env bash
# memory-scope-gate.sh: enforce .harness/memory-scopes.json on memory writes.
#
# PreToolUse-style hook: reads a tool-call JSON payload on stdin
# ({"tool_name": ..., "tool_input": {...}}), stamps required write metadata
# {author, scope, project}, and blocks writes that would leak personal-scope
# content into a wider scope (team/org), including <private>-tagged content,
# which never promotes. Fail-closed on policy violation; fail-open with a
# stderr note when the policy file is absent (solo/ad-hoc repos unaffected).
#
# Scope of a write is derived from the target path:
#   personal:  ~/.claude/projects/*/memory/, .claude/memory/
#   team:      .agents/memory/, memory/, docs/memory/
#   org:       paths declared under scopes.org in the policy (reserved)
#
# Client rules (independent of the scope policy): clients come from the
# shelfmark registry ($SHELFMARK_CLIENTS, default $RAG_HOME/clients.json,
# {slug: {db, roots}}), so the index and this gate share one client list.
# While a client is active (RAG_CLIENT, or cwd under a client root):
#   - a note (.md under a memory/ dir) outside every client root is GENERAL
#     memory and must declare `knowledge: technical|behavioral` in a closed
#     frontmatter, checked on the content as it will be after the edit;
#   - writing into ANOTHER client's roots is blocked;
#   - the client's own roots are always allowed (its vault, manifest, queue);
#   - MCP memory tools cannot carry the tag, so they always ask.
# A general write containing a term from <root>/.client/lexicon.txt is queued
# for review (default <root>/.client/review-queue.jsonl, so it leaves with the
# client) and the operator is asked (permissionDecision=ask), after the scope
# rules had their chance to block. A registry that exists but does not parse
# blocks memory writes: a broken client list must never read as "no clients".
#
# Exit 0 = allow, exit 2 = block (hook convention: deny the tool call).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
POLICY="$ROOT/.harness/memory-scopes.json"
CLIENTS_FILE="${SHELFMARK_CLIENTS:-${RAG_HOME:-$HOME/.shelfmark}/clients.json}"

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
[[ -z "$tool" ]] && exit 0

# Only gate memory-shaped writes: Write/Edit to memory paths, or MCP memory tools.
path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
content="$(printf '%s' "$payload" | jq -r '.tool_input.content // .tool_input.new_string // .tool_input.text // ([.tool_input.edits[]?.new_string] | join("\n"))')"

is_memory_tool=false
case "$tool" in
  *memory*|*Memory*|Write|Edit|MultiEdit) is_memory_tool=true ;;
esac
$is_memory_tool || exit 0

ask_reason=""
allow() {  # exit 0, asking the operator if a client rule queued a review
  if [[ -n "$ask_reason" ]]; then
    jq -cn --arg r "$ask_reason" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
  fi
  exit 0
}

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

# --- client rules -----------------------------------------------------------
fold() {  # macOS/Windows paths compare case-insensitively
  case "$(uname -s)" in Darwin|MINGW*|MSYS*|CYGWIN*) tr '[:upper:]' '[:lower:]' ;; *) cat ;; esac
}
abspath() {  # resolve even when the file does not exist yet
  local d; d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || d="$(dirname "$1")"
  printf '%s/%s' "$d" "$(basename "$1")"
}
client_of() {  # client_of <abs path> -> slug whose root contains it (deepest wins)
  local p best="" best_len=0 slug root r
  p="$(printf '%s' "$1" | fold)"
  while IFS=$'\t' read -r slug root; do
    [[ -z "$root" ]] && continue
    r="$(printf '%s' "${root%/}" | fold)"
    if [[ "$p" == "$r" || "$p" == "$r"/* ]] && (( ${#r} > best_len )); then
      best="$slug"; best_len=${#r}
    fi
  done < <(jq -r 'to_entries[] | .key as $k | .value.roots[]? | "\($k)\t\(.)"' "$CLIENTS_FILE")
  printf '%s' "$best"
}
post_edit() {  # the note as it will be after this tool call
  if [[ "$tool" == "Write" || ! -f "$path" ]]; then printf '%s' "$content"; return; fi
  printf '%s' "$payload" | jq -r --rawfile f "$path" '
    .tool_input as $i | (if $i.edits then $i.edits else [$i] end)
    | reduce .[] as $e ($f; if ($e.old_string // "") == "" then . else split($e.old_string) | join($e.new_string // "") end)'
}
has_knowledge_tag() {  # stdin: note; true when a CLOSED frontmatter declares the tag
  tr -d '\r' | awk -v re="^[[:space:]]*knowledge:[[:space:]]*[\"']?(technical|behavioral)[\"']?[[:space:]]*\$" '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { closed = 1; exit }
    $0 ~ re { tag = 1 }
    END { exit !(closed && tag) }'
}

is_mcp=true; case "$tool" in Write|Edit|MultiEdit) is_mcp=false ;; esac
abs_target=""; [[ -n "$path" ]] && abs_target="$(abspath "$path")"
is_note=$is_mcp
case "$(printf '%s' "$abs_target" | fold)" in */memory/*.md|*/org-memory/*.md) is_note=true ;; esac

if $is_note && [[ -e "$CLIENTS_FILE" ]]; then
  if ! jq -e 'type == "object" and all(.[]; type == "object" and ((.roots // []) | type == "array" and all(.[]; type == "string")))' \
      "$CLIENTS_FILE" >/dev/null 2>&1; then
    echo "memory-scope-gate: BLOCK - client registry $CLIENTS_FILE is unreadable or invalid; fix it before writing memory." >&2
    exit 2
  fi
  if [[ -n "${RAG_CLIENT:-}" ]]; then
    active="$RAG_CLIENT"; [[ "$active" == "none" ]] && active=""
    if [[ -n "$active" ]] && ! jq -e --arg s "$active" 'has($s)' "$CLIENTS_FILE" >/dev/null; then
      echo "memory-scope-gate: warning - RAG_CLIENT='$active' is not in $CLIENTS_FILE; gating as if it were." >&2
    fi
  else
    active="$(client_of "$(pwd -P)")"
  fi
  target_client=""; [[ -n "$abs_target" ]] && target_client="$(client_of "$abs_target")"

  if [[ -n "$active" && -n "$target_client" && "$target_client" != "$active" ]]; then
    echo "memory-scope-gate: BLOCK - writing into client '$target_client' while working for client '$active'." >&2
    exit 2
  fi
  if [[ -n "$active" && -z "$target_client" ]]; then
    # General memory written while working for a client.
    if $is_mcp; then
      scan="$(printf '%s' "$payload" | jq -c '.tool_input')"
      ask_reason="MCP memory tool $tool called while working for client '$active'; a knowledge tag cannot be checked here. Approve only if no client business is in it."
    else
      if ! post_edit | has_knowledge_tag; then
        echo "memory-scope-gate: BLOCK - general memory written while working for client '$active'." >&2
        echo "  Client business goes to the client's vault (a memory/ dir under its roots)." >&2
        echo "  A technical or behavioral lesson with the client's specifics removed may stay general:" >&2
        echo "  add 'knowledge: technical' or 'knowledge: behavioral' to its frontmatter." >&2
        exit 2
      fi
      scan="$content"
    fi
    hits="" queue="${MEMORY_REVIEW_QUEUE:-}" lexicons=0
    while IFS= read -r root; do
      [[ -z "$queue" ]] && queue="${root%/}/.client/review-queue.jsonl"
      lex="${root%/}/.client/lexicon.txt"
      [[ -f "$lex" ]] || continue
      lexicons=$((lexicons + 1))
      while IFS= read -r term; do
        [[ -z "$term" || "$term" == \#* ]] && continue
        printf '%s' "$scan" | grep -qiF -- "$term" && hits="$hits${hits:+, }$term"
      done < "$lex"
    done < <(jq -r --arg s "$active" '.[$s].roots[]?' "$CLIENTS_FILE")
    (( lexicons == 0 )) && echo "memory-scope-gate: warning - client '$active' has no .client/lexicon.txt; no term check ran." >&2
    if [[ -n "$hits" ]]; then
      queue="${queue:-${RAG_HOME:-$HOME/.shelfmark}/review-queue.jsonl}"
      mkdir -p "$(dirname "$queue")"
      jq -cn --arg c "$active" --arg p "${abs_target:-$tool}" --arg t "$hits" \
        '{ts: (now|floor), client: $c, path: $p, terms: ($t | split(", "))}' >> "$queue"
      ask_reason="${ask_reason:+$ask_reason }Memory note for GENERAL scope mentions client '$active' terms ($hits). Queued in $queue. Approve only if no client business remains."
    fi
  fi
fi

# --- scope rules (need the repo policy) ---------------------------------------
target_scope="$(scope_of "$path")"
[[ -z "$target_scope" ]] && allow  # not a memory path

if [[ ! -f "$POLICY" ]]; then
  echo "memory-scope-gate: no .harness/memory-scopes.json - fail-open (allow)" >&2
  allow
fi

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
allow
