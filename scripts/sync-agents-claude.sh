#!/usr/bin/env bash
# sync-agents-claude.sh — dual-emit CLAUDE.md from canonical AGENTS.md.
#
# Agent context files are split across tools: CLAUDE.md (~34%) and AGENTS.md
# (~32%) have near-equal adoption (arXiv 2602.14690). Maintaining both by hand
# guarantees drift; AGENTS.md is canonical here, CLAUDE.md is generated.
#
# Usage: bash scripts/sync-agents-claude.sh [--check]
#   (default)  regenerate CLAUDE.md from AGENTS.md
#   --check    exit 1 if CLAUDE.md is stale (CI drift-guard)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/AGENTS.md"
OUT="$ROOT/CLAUDE.md"
HEADER="<!-- GENERATED from AGENTS.md by scripts/sync-agents-claude.sh - edit AGENTS.md, not this file -->"

[ -f "$SRC" ] || { echo "sync-agents-claude: AGENTS.md not found" >&2; exit 2; }

generate() {
  printf '%s\n\n' "$HEADER"
  cat "$SRC"
}

if [ "${1:-}" = "--check" ]; then
  if [ ! -f "$OUT" ] || ! cmp -s <(generate) "$OUT"; then
    echo "sync-agents-claude: CLAUDE.md is stale - run scripts/sync-agents-claude.sh" >&2
    exit 1
  fi
  echo "sync-agents-claude: CLAUDE.md in sync"
  exit 0
fi

generate > "$OUT"
echo "sync-agents-claude: CLAUDE.md regenerated from AGENTS.md"
