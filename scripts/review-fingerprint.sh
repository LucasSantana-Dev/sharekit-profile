#!/usr/bin/env bash
# review-fingerprint.sh - compute a stable finding fingerprint for the review pack.
#
# Fingerprint = sha256(path + NUL + rule_id + NUL + normalized_snippet).
# Line numbers are NOT an input: the same snippet moved to a different line
# produces the same fingerprint, so findings survive force-push/rebase (spec D5).
#
# Normalization: whitespace-only lines are stripped and every run of whitespace
# is collapsed to a single space, then edges are trimmed.
#
# Usage:
#   scripts/review-fingerprint.sh <path> <rule_id> [snippet words...]
#   printf '%s' "$snippet" | scripts/review-fingerprint.sh <path> <rule_id>
set -u

if [ "$#" -lt 2 ]; then
  echo "usage: review-fingerprint.sh <path> <rule_id> [snippet...]" >&2
  exit 2
fi

FINDING_PATH="$1"
RULE_ID="$2"
shift 2

if [ "$#" -gt 0 ]; then
  SNIPPET="$*"
else
  SNIPPET="$(cat)"
fi

NORMALIZED="$(printf '%s' "$SNIPPET" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"

printf '%s\0%s\0%s' "$FINDING_PATH" "$RULE_ID" "$NORMALIZED" | shasum -a 256 | awk '{print $1}'
