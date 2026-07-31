#!/usr/bin/env bash
# check-ac-coverage.sh — deterministic task-to-requirement traceability gate.
#
# Team-scale equivalent of checklist-gate: every task in a tasks/plan file must
# trace to a requirement ID (REQ-n) declared in the spec's requirements.md.
#
# Usage:
#   bash hooks/check-ac-coverage.sh --tasks <tasks.md> --requirements <requirements.md>
#   bash hooks/check-ac-coverage.sh --spec-dir specs/<feature>/
# Exit 1 listing untraceable tasks; exit 0 when every task traces.

set -euo pipefail

TASKS=""
REQS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks) TASKS="$2"; shift 2 ;;
    --requirements) REQS="$2"; shift 2 ;;
    --spec-dir) TASKS="$2/tasks.md"; REQS="$2/requirements.md"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$TASKS" || -z "$REQS" ]] && { echo "usage: check-ac-coverage.sh --tasks T --requirements R | --spec-dir D" >&2; exit 2; }
[[ ! -f "$TASKS" ]] && { echo "check-ac-coverage: tasks file not found: $TASKS" >&2; exit 2; }
[[ ! -f "$REQS" ]] && { echo "check-ac-coverage: requirements file not found: $REQS" >&2; exit 2; }

# Declared requirement IDs in the spec.
declared="$(grep -oE 'REQ-[0-9]+' "$REQS" | sort -u)"

# Task rows: markdown table rows whose first cell is a number, or "- [ ]"/"- [x]" items.
tasks="$(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\||^- \[[ x]\]' "$TASKS" || true)"

if [[ -z "$tasks" ]]; then
  echo "check-ac-coverage: no task rows found in $TASKS" >&2
  exit 1
fi

fails=0
while IFS= read -r row; do
  refs="$(printf '%s' "$row" | grep -oE 'REQ-[0-9]+' | sort -u || true)"
  if [[ -z "$refs" ]]; then
    echo "UNTRACED: ${row:0:100}"
    fails=$((fails + 1))
    continue
  fi
  for ref in $refs; do
    if ! printf '%s\n' "$declared" | grep -qx "$ref"; then
      echo "UNKNOWN-REQ: $ref not declared in $REQS (row: ${row:0:80})"
      fails=$((fails + 1))
    fi
  done
done <<< "$tasks"

if [[ "$fails" -gt 0 ]]; then
  echo "check-ac-coverage: FAIL - $fails traceability violation(s)" >&2
  exit 1
fi
echo "check-ac-coverage: OK - every task traces to a declared requirement"
exit 0
