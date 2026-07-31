#!/usr/bin/env bash
# merge-policy-fragments.sh — merge .harness/policy.d/*.json drop-in fragments
# into a single effective policy JSON on stdout.
#
# Merge semantics (documented in .harness/README.md):
#   - Fragments load in lexicographic filename order; use numeric prefixes
#     (10-platform.json, 20-security.json) for deterministic ordering.
#   - Objects merge recursively.
#   - Arrays union (concatenate + dedupe), so deny lists compose across layers.
#   - Scalars: the fragment with the higher prefix wins.
#   - Fail-closed: any invalid JSON fragment aborts with exit 1 and no output.
#
# Usage: merge-policy-fragments.sh [policy.d-dir]   (default: .harness/policy.d)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_D="${1:-$ROOT/.harness/policy.d}"

if [[ ! -d "$POLICY_D" ]]; then
  echo '{}'
  exit 0
fi

fragments=()
while IFS= read -r f; do
  fragments+=("$f")
done < <(find "$POLICY_D" -maxdepth 1 -type f -name '*.json' | LC_ALL=C sort)

if [[ ${#fragments[@]} -eq 0 ]]; then
  echo '{}'
  exit 0
fi

# Fail-closed validation: every fragment must be a valid JSON object.
for f in "${fragments[@]}"; do
  if ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then
    echo "ERROR: invalid policy fragment (not a JSON object): $f" >&2
    exit 1
  fi
done

jq -s '
  def merge($a; $b):
    if ($a | type) == "object" and ($b | type) == "object" then
      (($a | keys) + ($b | keys) | unique) as $ks
      | reduce $ks[] as $k ({};
          if ($a | has($k)) and ($b | has($k)) then .[$k] = merge($a[$k]; $b[$k])
          elif $b | has($k) then .[$k] = $b[$k]
          else .[$k] = $a[$k] end)
    elif ($a | type) == "array" and ($b | type) == "array" then
      ($a + $b) | unique
    else
      $b
    end;
  reduce .[] as $frag ({}; merge(.; $frag))
' "${fragments[@]}"
