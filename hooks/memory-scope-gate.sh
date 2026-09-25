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
# Client rules (independent of the scope policy): clients come from the
# shelfmark registry ($SHELFMARK_CLIENTS, default $RAG_HOME/clients.json,
# {slug: {db, roots}}), so the index and this gate share one client list.
# While a client is active (RAG_CLIENT, or cwd under a client root), a write
# to GENERAL memory must declare `knowledge: technical|behavioral` in its
# frontmatter; client business goes to the client's own vault (any path
# under its roots, always allowed). A general write containing a term from
# <root>/.client/lexicon.txt is not blocked: it is queued for review and the
# operator is asked (permissionDecision=ask).
#
# Exit 0 = allow, exit 2 = block (hook convention: deny the tool call).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
POLICY="$ROOT/.harness/memory-scopes.json"
CLIENTS_FILE="${SHELFMARK_CLIENTS:-${RAG_HOME:-$HOME/.shelfmark}/clients.json}"
REVIEW_QUEUE="${MEMORY_REVIEW_QUEUE:-${RAG_HOME:-$HOME/.shelfmark}/review-queue.jsonl}"

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
  done < <(jq -r 'to_entries[] | .key as $k | .value.roots[]? | "\($k)\t\(.)"' "$CLIENTS_FILE" 2>/dev/null)
  printf '%s' "$best"
}

if [[ -n "$path" && -s "$CLIENTS_FILE" ]]; then
  abs_target="$(abspath "$path")"
  target_client="$(client_of "$abs_target")"
  if [[ -n "${RAG_CLIENT:-}" ]]; then
    active="$RAG_CLIENT"; [[ "$active" == "none" ]] && active=""
  else
    active="$(client_of "$(pwd -P)")"
  fi
  if [[ -n "$active" && -z "$target_client" && -n "$(scope_of "$path")" ]]; then
    # General memory written while working for a client.
    fm_source="$content"
    [[ "$tool" != "Write" && -f "$path" ]] && fm_source="$(cat "$path")"
    frontmatter="$(printf '%s\n' "$fm_source" | awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}')"
    if ! printf '%s\n' "$frontmatter" | grep -Eq '^knowledge:[[:space:]]*(technical|behavioral)[[:space:]]*$'; then
      echo "memory-scope-gate: BLOCK - general memory written while working for client '$active'." >&2
      echo "  Client business goes to the client's vault (a memory/ dir under its roots)." >&2
      echo "  A technical or behavioral lesson with the client's specifics removed may stay general:" >&2
      echo "  add 'knowledge: technical' or 'knowledge: behavioral' to its frontmatter." >&2
      exit 2
    fi
    hits=""
    while IFS= read -r root; do
      lex="${root%/}/.client/lexicon.txt"
      [[ -f "$lex" ]] || continue
      while IFS= read -r term; do
        [[ -z "$term" || "$term" == \#* ]] && continue
        printf '%s' "$content" | grep -qiF -- "$term" && hits="$hits${hits:+, }$term"
      done < "$lex"
    done < <(jq -r --arg s "$active" '.[$s].roots[]?' "$CLIENTS_FILE")
    if [[ -n "$hits" ]]; then
      mkdir -p "$(dirname "$REVIEW_QUEUE")"
      jq -cn --arg c "$active" --arg p "$abs_target" --arg t "$hits" \
        '{ts: (now|floor), client: $c, path: $p, terms: ($t | split(", "))}' >> "$REVIEW_QUEUE"
      jq -cn --arg r "Memory note for GENERAL scope mentions client '$active' terms ($hits). Queued in $REVIEW_QUEUE. Approve only if no client business remains." \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
      exit 0
    fi
  fi
fi

# --- scope rules (need the repo policy) ---------------------------------------
if [[ ! -f "$POLICY" ]]; then
  echo "memory-scope-gate: no .harness/memory-scopes.json - fail-open (allow)" >&2
  exit 0
fi

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
