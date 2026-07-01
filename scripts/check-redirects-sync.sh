#!/usr/bin/env bash
# check-redirects-sync.sh — verify .harness/redirects.yaml and docs/composites.md's
# "Replacements for archived wrappers" table agree on the same set of archived
# skill names. Two hand-maintained representations of one mapping drift silently
# without this — catches an added/removed entry in one that wasn't mirrored in
# the other.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REDIRECTS="$ROOT/.harness/redirects.yaml"
COMPOSITES="$ROOT/docs/composites.md"

if [[ ! -f "$REDIRECTS" ]]; then
  echo "check-redirects-sync: $REDIRECTS not found — nothing to check" >&2
  exit 0
fi
if [[ ! -f "$COMPOSITES" ]]; then
  echo "check-redirects-sync: $COMPOSITES not found — nothing to check" >&2
  exit 0
fi

redirects_names="$(rg -o '^\s*- archived: (\S+)' -r '$1' "$REDIRECTS" | sort -u)"

# First-column backtick names from the "Replacements for archived wrappers" table.
composites_names="$(awk '
  /^## Replacements for archived wrappers/ { capture=1; next }
  capture && /^---/ { exit }
  capture && /^\|/ { print }
' "$COMPOSITES" | rg -v '^\|---' | awk -F'|' '{print $2}' | rg -o '`[a-z0-9_-]+`' | tr -d '`' | sort -u)"

missing_in_composites="$(comm -23 <(echo "$redirects_names") <(echo "$composites_names") || true)"
missing_in_redirects="$(comm -13 <(echo "$redirects_names") <(echo "$composites_names") || true)"

status=0
if [[ -n "$missing_in_composites" ]]; then
  echo "ERROR: archived skills in redirects.yaml but missing from docs/composites.md table:" >&2
  echo "$missing_in_composites" | sed 's/^/  - /' >&2
  status=1
fi
if [[ -n "$missing_in_redirects" ]]; then
  echo "ERROR: archived skills in docs/composites.md table but missing from redirects.yaml:" >&2
  echo "$missing_in_redirects" | sed 's/^/  - /' >&2
  status=1
fi

if [[ $status -eq 0 ]]; then
  count="$(echo "$redirects_names" | wc -l | tr -d ' ')"
  echo "check-redirects-sync: OK — redirects.yaml and docs/composites.md agree on $count archived skill names"
fi
exit $status
