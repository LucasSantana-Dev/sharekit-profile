#!/usr/bin/env bash
# check-spec-drift.sh: spec-anchored lifecycle gate (team-expansion Phase 6).
#
# Spec maintenance is every SDD tool's weak point: the spec stops matching the
# work. Two deterministic checks on staged changes (pre-commit) or a given
# diff range:
#
#   FAIL  requirements.md changed without tasks.md changing in the same spec
#         (requirements moved, traceability went stale)
#   WARN  code changed without any spec change while feature specs exist
#         (possible spec-less work; advisory - many commits legitimately don't
#          touch the spec: fixes, chores, other features)
#
# Usage: bash hooks/check-spec-drift.sh [--staged | --range A..B]
# Exit 1 on FAIL findings, 0 otherwise.

set -euo pipefail

MODE="--staged"
[ $# -ge 1 ] && MODE="$1"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT"

case "$MODE" in
  --staged) CHANGED="$(git diff --cached --name-only)" ;;
  --range)  CHANGED="$(git diff --name-only "$2")" ;;
  *) echo "usage: check-spec-drift.sh [--staged | --range A..B]" >&2; exit 2 ;;
esac
[ -z "$CHANGED" ] && exit 0

fails=0

# FAIL: requirements.md touched without tasks.md in the same spec dir.
for req in $(printf '%s\n' "$CHANGED" | grep -E '^specs/[^/]+/requirements\.md$' || true); do
  specdir="$(dirname "$req")"
  if ! printf '%s\n' "$CHANGED" | grep -q "^$specdir/tasks\.md$"; then
    echo "SPEC-DRIFT: $req changed but $specdir/tasks.md did not" >&2
    fails=$((fails + 1))
  fi
done

# WARN: feature specs exist and code changed without any spec change.
feature_specs="$(find specs -mindepth 1 -maxdepth 1 -type d ! -name '_template' 2>/dev/null | head -1 || true)"
if [ -n "$feature_specs" ]; then
  code_changed="$(printf '%s\n' "$CHANGED" | grep -vE '^specs/|^docs/|\.md$|^tests/' || true)"
  spec_changed="$(printf '%s\n' "$CHANGED" | grep -E '^specs/' || true)"
  if [ -n "$code_changed" ] && [ -z "$spec_changed" ]; then
    echo "spec-drift: WARN - code changed with no spec update; if this belongs to a spec'd feature, reference and update specs/<feature>/" >&2
  fi
fi

[ "$fails" -gt 0 ] && { echo "check-spec-drift: FAIL - $fails drift violation(s)" >&2; exit 1; }
exit 0
