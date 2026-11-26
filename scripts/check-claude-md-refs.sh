#!/usr/bin/env bash
# Fails when claude/CLAUDE.md names a standard (*.md) or hook (*.sh) that this repo
# does not ship. Cloud threads read CLAUDE.md straight from this repo, with no
# ~/.claude behind it, so every reference has to resolve here.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
doc="$root/claude/CLAUDE.md"
missing=0

# Standards: every foo.md mentioned (table cells, "standards/foo.md", backticks).
for name in $(grep -oE '[a-z0-9-]+\.md' "$doc" | sort -u); do
  case "$name" in CLAUDE.md|README.md) continue ;; esac
  if [ ! -f "$root/claude/standards/$name" ]; then
    echo "missing standard: claude/standards/$name"
    missing=1
  fi
done

# Hooks: every foo.sh mentioned.
for name in $(grep -oE '[a-z0-9-]+\.sh' "$doc" | sort -u); do
  if [ ! -f "$root/claude/hooks/$name" ]; then
    echo "missing hook: claude/hooks/$name"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "claude/CLAUDE.md cites files this repo does not ship" >&2
  exit 1
fi
echo "claude/CLAUDE.md references: ok"
