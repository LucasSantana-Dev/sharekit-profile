#!/usr/bin/env bash
# check-harness-manifest.sh — verify .harness/manifest.json fingerprints + policy invariants.
# Exit 0 = all checks pass; exit 1 = mismatch or invariant violation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/.harness/manifest.json"
POLICY="$ROOT/.harness/mcp-policy.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest not found at $MANIFEST" >&2
  exit 1
fi
if [[ ! -f "$POLICY" ]]; then
  echo "ERROR: mcp-policy.json not found at $POLICY" >&2
  exit 1
fi

status=0

# --- Fingerprint verification ---
# Iterate over the files object; compare recorded sha256 vs actual.
while IFS=$'\t' read -r relpath recorded; do
  actual="$ROOT/$relpath"
  if [[ ! -f "$actual" ]]; then
    echo "ERROR: tracked file missing: $relpath" >&2
    status=1
    continue
  fi
  computed="$(shasum -a 256 "$actual" | awk '{print $1}')"
  if [[ "$recorded" != "$computed" ]]; then
    echo "ERROR: fingerprint mismatch for $relpath" >&2
    echo "  manifest: $recorded" >&2
    echo "  actual:   $computed" >&2
    status=1
  fi
done < <(jq -r '.files | to_entries[] | [.key, .value] | @tsv' "$MANIFEST")

# --- Policy invariants ---
default_deny="$(jq -r '.defaultDeny' "$POLICY")"
if [[ "$default_deny" != "true" ]]; then
  echo "ERROR: invariant violated — defaultDeny must be true (got: $default_deny)" >&2
  status=1
fi

dp_count="$(jq -r '.dangerousPatterns | length' "$POLICY")"
if [[ "$dp_count" -eq 0 ]]; then
  echo "ERROR: invariant violated — dangerousPatterns array is empty" >&2
  status=1
fi

as_count="$(jq -r '.approvedServers | length' "$POLICY")"
if [[ "$as_count" -eq 0 ]]; then
  echo "ERROR: invariant violated — approvedServers array is empty" >&2
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "OK: harness manifest fingerprints + policy invariants verified"
  exit 0
fi
exit 1