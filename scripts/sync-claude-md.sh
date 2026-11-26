#!/usr/bin/env bash
# Generate ~/.claude/CLAUDE.md from claude/CLAUDE.md on origin/main of this repo.
# The repo is the single source; this file only flows repo -> ~/.claude.
#
# Personal or machine-only rules go in ~/.claude/CLAUDE.local.md (never in this
# public repo). When that file exists, the generated CLAUDE.md imports it with
# an @ line, which Claude Code resolves from the user-level CLAUDE.md.
#
# Drift guard: the hash of the last generated file is kept in
# ~/.claude/.claude-md-sync.sha. If ~/.claude/CLAUDE.md changed since then
# (someone edited it by hand), it is backed up and the change is reported
# before being overwritten, so the edit can be moved to the repo or the
# local layer.
#
# Usage: scripts/sync-claude-md.sh [--check]
#   --check  only report whether ~/.claude/CLAUDE.md is in step; write nothing.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dest="${CLAUDE_HOME:-$HOME/.claude}"
target="$dest/CLAUDE.md"
local_layer="$dest/CLAUDE.local.md"
stamp="$dest/.claude-md-sync.sha"

git -C "$repo" fetch -q origin main
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
git -C "$repo" show origin/main:claude/CLAUDE.md > "$tmp"
if [ -f "$local_layer" ]; then
  printf '\n## Local layer\n\n@~/.claude/CLAUDE.local.md\n' >> "$tmp"
fi

hash_of() { git hash-object "$1"; }
new_hash="$(hash_of "$tmp")"

if [ -f "$target" ] && [ "$(hash_of "$target")" = "$new_hash" ]; then
  echo "CLAUDE.md: already in step with origin/main - skipping"
  exit 0
fi

drift=0
if [ -f "$target" ] && [ -f "$stamp" ] && [ "$(hash_of "$target")" != "$(cat "$stamp")" ]; then
  drift=1
fi

if [ "${1:-}" = "--check" ]; then
  [ "$drift" -eq 1 ] && echo "DRIFT: $target was edited by hand since the last sync"
  echo "CLAUDE.md: out of step with origin/main (run without --check to update)"
  exit 1
fi

if [ -f "$target" ]; then
  backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$target" "$backup"
  [ "$drift" -eq 1 ] && echo "DRIFT: $target was edited by hand since the last sync; kept as $backup. Move that edit to claude/CLAUDE.md in the repo or to $local_layer."
fi

cp "$tmp" "$target"
printf '%s\n' "$new_hash" > "$stamp"
echo "CLAUDE.md: generated from origin/main ($(git -C "$repo" rev-parse --short origin/main))"
