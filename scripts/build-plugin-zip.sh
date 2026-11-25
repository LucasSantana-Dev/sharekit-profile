#!/usr/bin/env bash
# Builds the sharekit plugin as a zip for "Add > Upload plugin" on claude.ai.
# Plugins installed from a marketplace stay local; an uploaded plugin syncs to
# every Claude Code session signed in to the account, cloud sessions included.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/dist/sharekit-plugin.zip}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pkg="$work/sharekit"
mkdir -p "$pkg/.claude-plugin"
cp -r "$root/claude/skills" "$root/claude/agents" "$root/claude/hooks" "$pkg/"
rm -rf "$pkg/skills/.archive"

python3 - "$root/.claude-plugin/marketplace.json" "$pkg/.claude-plugin/plugin.json" <<'PY'
import json, sys
entry = next(p for p in json.load(open(sys.argv[1]))["plugins"] if p["name"] == "sharekit")
keys = ("name", "description", "version", "author", "license", "keywords")
json.dump({k: entry[k] for k in keys if k in entry}, open(sys.argv[2], "w"), indent=2)
PY

mkdir -p "$(dirname "$out")"
rm -f "$out"
(cd "$pkg" && zip -qr "$out" .)
echo "built $out"
