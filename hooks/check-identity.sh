#!/usr/bin/env bash
# check-identity.sh — verify git identity matches the repo-declared expected
# identity. Highest-value multi-operator control: wrong-identity commits are
# the most common multi-operator accident (research track 6, 2026-07-30).
#
# Declaration: .harness/identity.json — {"email": "..."} or {"emails": [...]}.
# No declaration (or empty) -> pass-through, so solo/ad-hoc repos are unaffected.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
DECL="$ROOT/.harness/identity.json"
[ ! -f "$DECL" ] && exit 0

actual="$(git config user.email || true)"

if jq -e '.emails' "$DECL" >/dev/null 2>&1; then
  if jq -e --arg a "$actual" '.emails | index($a)' "$DECL" >/dev/null 2>&1; then
    exit 0
  fi
  echo "check-identity: user.email '$actual' not in .harness/identity.json emails[]" >&2
  echo "  fix: git config user.email <your-declared-email> (or add it to the declaration)" >&2
  exit 1
fi

expected="$(jq -r '.email // empty' "$DECL")"
[ -z "$expected" ] && exit 0
[ "$actual" = "$expected" ] && exit 0

echo "check-identity: user.email '$actual' != expected '$expected' (.harness/identity.json)" >&2
echo "  fix: git config user.email $expected" >&2
exit 1
