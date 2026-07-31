#!/usr/bin/env bash
# Marketplace drift-guard (CI-safe, self-contained). Validates
# .claude-plugin/marketplace.json: JSON parses, every plugin has
# name/description/version, every source is a relative path starting with ./
# that exists on disk, and every curated-*.txt list stays in sync with the
# plugin source dir it feeds (same failure class as scripts/check-catalog.sh:
# a curated entry with no file, or a curated concern with no plugin, fails).
# Usage: check-marketplace.sh [ROOT]  (ROOT defaults to the repo root)
set -euo pipefail
if [ $# -ge 1 ]; then
  ROOT="$(cd "$1" && pwd)"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
MK="$ROOT/.claude-plugin/marketplace.json"

fail=0
err() { echo "FAIL: $1"; fail=1; }

if [ ! -f "$MK" ]; then
  echo "FAIL: $MK not found"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required to parse marketplace.json"
  exit 1
fi

# Structural pass: parse JSON, enforce required fields and ./ source shape.
# Emits one "SRC <name> <source>" line per plugin for the path pass below.
src_lines=$(python3 - "$MK" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (OSError, ValueError) as e:
    print(f"ERR\tmarketplace.json does not parse: {e}")
    sys.exit(0)
if not isinstance(data.get("name"), str) or not data["name"]:
    print("ERR\tmarketplace missing name")
if not isinstance(data.get("owner"), dict):
    print("ERR\tmarketplace missing owner")
plugins = data.get("plugins")
if not isinstance(plugins, list) or not plugins:
    print("ERR\tplugins missing or empty")
    sys.exit(0)
for p in plugins:
    name = p.get("name") if isinstance(p, dict) else None
    label = name or "?"
    for field in ("name", "description", "version"):
        if not isinstance(p, dict) or not p.get(field):
            print(f"ERR\tplugin {label} missing {field}")
    src = p.get("source") if isinstance(p, dict) else None
    if not isinstance(src, str) or not src.startswith("./"):
        print(f"ERR\tplugin {label} source must be a relative path starting with ./")
    elif name:
        print(f"SRC\t{name}\t{src}")
PY
)

plugin_count=0
sources=""
while IFS=$'\t' read -r tag a b; do
  case "$tag" in
    ERR) err "$a" ;;
    SRC)
      plugin_count=$((plugin_count + 1))
      sources="$sources$b
"
      if [ ! -e "$ROOT/${b#./}" ]; then
        err "plugin $a source $b does not exist"
      fi
      ;;
  esac
done <<< "$src_lines"

# Curated sync pass: each curated list must have a marketplace plugin covering
# its source dir, and every entry in the list must exist under that dir.
curated_count=0
sync_pair() { # curated file, source dir
  local list="$ROOT/$1" dir="$2"
  [ -f "$list" ] || return 0
  if ! printf '%s' "$sources" | grep -Fxq "$dir"; then
    err "$1 has no marketplace plugin covering $dir"
    return
  fi
  local entry
  while IFS= read -r entry; do
    case "$entry" in ''|\#*) continue ;; esac
    curated_count=$((curated_count + 1))
    if [ ! -e "$ROOT/$dir/$entry" ]; then
      err "$1 lists $entry but $dir/$entry does not exist"
    fi
  done < "$list"
}
sync_pair curated-skills.txt     ./claude/skills
sync_pair curated-hooks.txt      ./claude/hooks
sync_pair curated-standards.txt  ./claude/standards
sync_pair curated-agents.txt     ./claude/agents

# Channel gate: the marketplace metadata version must track the canonical
# release stream (.release-please-manifest.json). Version drift between the
# two silently breaks the stable/latest channel contract (teams pinning
# `stable` get a listing that lies about what it contains).
RPM="$ROOT/.release-please-manifest.json"
if [ -f "$RPM" ]; then
  channel_version="$(jq -r '.["."] // empty' "$RPM")"
  mk_version="$(jq -r '.metadata.version // empty' "$MK")"
  if [ -n "$channel_version" ] && [ "$mk_version" != "$channel_version" ]; then
    err "marketplace metadata.version $mk_version != release channel $channel_version (.release-please-manifest.json)"
  fi
fi

if [ "$fail" = 0 ]; then
  echo "marketplace checks passed: $plugin_count plugins, $curated_count curated entries verified"
fi
exit "$fail"
