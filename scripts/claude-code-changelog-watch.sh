#!/usr/bin/env bash
# List Claude Code changelog lines that touch the harness surface (hooks,
# skills, plugins, subagents, settings, permissions, MCP, models, removals)
# for every release newer than the one recorded in .harness/claude-code-reviewed.
#
# Usage: claude-code-changelog-watch.sh [CHANGELOG_FILE]
#   Without a file it downloads the public changelog. Prints a Markdown report
#   to stdout; prints nothing when there is no newer release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVIEWED_FILE="$ROOT/.harness/claude-code-reviewed"
URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

reviewed="$(tr -d '[:space:]' < "$REVIEWED_FILE")"
if [ $# -ge 1 ]; then
  changelog="$(cat "$1")"
else
  changelog="$(curl -fsSL "$URL")"
fi

printf '%s\n' "$changelog" | python3 -c '
import re, sys

reviewed = tuple(int(x) for x in sys.argv[1].split("."))
pattern = re.compile(
    r"hook|skill|plugin|subagent|agent frontmatter|frontmatter|settings|permission"
    r"|mcp|marketplace|model|deprecat|remov|breaking|no longer|CLAUDE\.md|memory"
    r"|statusline|auto mode|effort|compact",
    re.I,
)
version, hits, newest = None, {}, None
for line in sys.stdin:
    m = re.match(r"^## (\d+(?:\.\d+)+)\s*$", line)
    if m:
        version = m.group(1)
        newest = newest or version
        continue
    if version and line.startswith("- ") and pattern.search(line):
        if tuple(int(x) for x in version.split(".")) > reviewed:
            hits.setdefault(version, []).append(line.rstrip())
if not hits:
    sys.exit(0)
print("Claude Code releases after %s that touch the harness surface (newest: %s).\n" % (sys.argv[1], newest))
for v in hits:
    print("### %s\n" % v)
    print("\n".join(hits[v]) + "\n")
print("When reviewed, set `.harness/claude-code-reviewed` to %s." % newest)
' "$reviewed"
