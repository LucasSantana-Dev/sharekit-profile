#!/usr/bin/env bash
# auto-context-pack.sh — injects RAG-packed context into UserPromptSubmit
#
# Exit paths (all logged for kill-gate measurement):
#   off          — env var CLAUDE_AUTO_CONTEXT_PACK=off
#   short        — prompt <24 chars (chitchat, slash commands)
#   long-workflow — agentic skill prompt (parallel-phases etc.)
#   no-match     — regex didn't match coding-intent keywords
#   no-tool      — RAG venv or pack.py missing
#   timeout      — pack.py ran past 20s or returned empty
#   oversize     — output exceeded 3500 bytes (discarded)
#   graph        — graphify knowledge-graph context injected (RAG skipped)
#   graph-miss   — graph exists but query empty/oversize; fell through to RAG
#   green        — context pack injected
set -euo pipefail
LOG=~/.claude/hooks/auto-context-pack.log
mkdir -p "$(dirname "$LOG")" 2>/dev/null || LOG=/dev/null
TS=$(date -u +%FT%TZ)

# `timeout` is absent on stock macOS: use gtimeout, else a python3 stdlib shim, else no limit.
if ! command -v timeout >/dev/null 2>&1; then
  if command -v gtimeout >/dev/null 2>&1; then
    timeout() { gtimeout "$@"; }
  elif command -v python3 >/dev/null 2>&1; then
    timeout() {
      python3 -c 'import subprocess, sys
try:
    sys.exit(subprocess.run(sys.argv[2:], timeout=float(sys.argv[1])).returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
except OSError:
    sys.exit(127)' "$@"
    }
  else
    timeout() { shift; "$@"; }
  fi
fi

# Env-var kill switch (per-shell disable)
if [ "${CLAUDE_AUTO_CONTEXT_PACK:-on}" = "off" ]; then
  echo "off $TS env-disabled" >> "$LOG"
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
PROMPT=$(python3 -c 'import json,sys
try:
 d=json.loads(sys.stdin.read() or "{}")
 print(d.get("prompt") or d.get("user_prompt") or "")
except Exception:
 print("")' <<< "$INPUT")

if [ ${#PROMPT} -lt 24 ]; then
  echo "short $TS prompt-len=${#PROMPT}" >> "$LOG"
  exit 0
fi

# Skip for long-running agentic workflows that produce their own context.
# These eat the per-turn budget faster than the pack can help.
LONG_WORKFLOW='^[[:space:]]*/?(parallel-phases|orchestrate|loop|dispatch|scope-and-execute|backlog|three-man-team|subagent-driven-development)\b'
if printf '%s' "$PROMPT" | grep -qiE "$LONG_WORKFLOW"; then
  echo "long-workflow $TS prompt-len=${#PROMPT}" >> "$LOG"
  exit 0
fi

# Coding-intent regex. Conservative — every match costs up to 20s latency.
# Widened 2026-05-13: + optimize|audit|analyze|build|trace|verify|harden|wire
TRIGGER='implement|refactor|fix|debug|investigate|replace|migrate|review|ship|plan|design|optimize|audit|analyze|build|trace|verify|harden|wire'
if ! printf '%s' "$PROMPT" | grep -qiE "$TRIGGER"; then
  echo "no-match $TS prompt-len=${#PROMPT}" >> "$LOG"
  exit 0
fi

# Graph-first: if the project has a graphify knowledge graph, answer from it.
# A BFS graph query is budget-capped and structural — cheaper and more precise
# than the RAG pack for codebase questions. Falls through to RAG on any miss.
CWD=$(python3 -c 'import json,sys
try:
 d=json.loads(sys.stdin.read() or "{}")
 print(d.get("cwd") or "")
except Exception:
 print("")' <<< "$INPUT")
[ -z "$CWD" ] && CWD="$PWD"

# Cooperative-mode guard (standards/cooperative-mode.md): the RAG pack contains
# personal-vault content (memory/plans/handoffs). In team repos, allow only the
# repo-local graph context (handled above); skip the pack entirely.
if [ "$("$HOME/.claude/scripts/repo-mode.sh" "$CWD" 2>/dev/null || echo solo)" = "cooperative" ]; then
  echo "coop-skip $TS prompt-len=${#PROMPT}" >> "$LOG"
  exit 0
fi

if [ -f "$CWD/graphify-out/graph.json" ] && command -v graphify &>/dev/null; then
  GRAPH_OUT=$(cd "$CWD" && timeout 15 graphify query "$PROMPT" --budget 500 2>/dev/null || true)
  if [ -n "$GRAPH_OUT" ] && [ ${#GRAPH_OUT} -le 3500 ]; then
    echo "graph $TS prompt-len=${#PROMPT} graph-bytes=${#GRAPH_OUT}" >> "$LOG"
    printf '# Knowledge graph context (graphify — cite source_location when using)\n%s\n' "$GRAPH_OUT"
    exit 0
  fi
  echo "graph-miss $TS prompt-len=${#PROMPT} graph-bytes=${#GRAPH_OUT}" >> "$LOG"
fi

PACK_TOOL="${DEV_ROOT:-}/rag-index/venv/bin/python"
PACK_SCRIPT="${DEV_ROOT:-}/rag-index/pack.py"
if [ -z "${DEV_ROOT:-}" ] || [ ! -x "$PACK_TOOL" ] || [ ! -f "$PACK_SCRIPT" ]; then
  echo "no-tool $TS" >> "$LOG"
  exit 0
fi

# Budget reduced 2026-05-15: 1800 -> 800 to stop autocompact thrash.
# Hard cap on output bytes — discard if pack returns oversize.
OUTPUT=$(timeout 20 "$PACK_TOOL" "$PACK_SCRIPT" "$PROMPT" --budget 800 --diff 2>/dev/null || true)
if [ -z "$OUTPUT" ]; then
  echo "timeout $TS prompt-len=${#PROMPT}" >> "$LOG"
  exit 0
fi
if [ ${#OUTPUT} -gt 3500 ]; then
  echo "oversize $TS prompt-len=${#PROMPT} pack-bytes=${#OUTPUT} (discarded)" >> "$LOG"
  exit 0
fi

echo "green $TS prompt-len=${#PROMPT} pack-bytes=${#OUTPUT}" >> "$LOG"
printf '%s\n' "$OUTPUT"
