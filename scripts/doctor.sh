#!/usr/bin/env bash
# Dependency preflight: list tools the hooks expect, before wiring hooks.
# Non-fatal by design: always exits 0 unless --strict is passed and a required tool is missing.
# Usage: scripts/doctor.sh [--strict]
# Env: SHAREKIT_DOCTOR_PATH overrides PATH for lookups (used by tests).
set -u

strict=0
[ "${1:-}" = "--strict" ] && strict=1
[ -n "${SHAREKIT_DOCTOR_PATH:-}" ] && PATH="$SHAREKIT_DOCTOR_PATH"

missing_required=0
missing_optional=0

have() { command -v "$1" >/dev/null 2>&1; }

check() { # check <label> <purpose> <install hint> <cmd...>
  local label="$1" purpose="$2" hint="$3"
  shift 3
  [ "$#" -eq 0 ] && set -- "$label"
  local c
  for c in "$@"; do
    if have "$c"; then
      echo "ok       $label ($purpose)"
      return 0
    fi
  done
  return 1
}

req() {
  local label="$1" purpose="$2" hint="$3"
  shift 3
  if ! check "$label" "$purpose" "$hint" "$@"; then
    echo "MISSING  $label ($purpose). Install: $hint"
    missing_required=$((missing_required + 1))
  fi
}

opt() {
  local label="$1" purpose="$2" hint="$3"
  shift 3
  if ! check "$label" "$purpose" "$hint" "$@"; then
    echo "optional $label not found ($purpose). Install: $hint"
    missing_optional=$((missing_optional + 1))
  fi
}

echo "sharekit dependency preflight"
req jq      "hook JSON parsing"      "brew install jq | winget install jqlang.jq"
req gh      "PR and issue hooks"     "brew install gh | winget install GitHub.cli"
req sqlite3 "memory and index state" "brew install sqlite | winget install SQLite.SQLite"
req node    "npx @lucassantana/sharekit" "brew install node | winget install OpenJS.NodeJS.LTS"
req python  "gates and evals"        "brew install python | winget install Python.Python.3.12" python3 python
opt rtk      "output compression"    "see the rtk project docs"
opt graphify "knowledge graph queries" "see the graphify project docs"

if [ "$missing_required" -gt 0 ]; then
  echo "warning: $missing_required required tool(s) missing; affected hooks will no-op or warn."
elif [ "$missing_optional" -gt 0 ]; then
  echo "all required tools present; $missing_optional optional tool(s) missing."
else
  echo "all tools present."
fi

if [ "$strict" -eq 1 ] && [ "$missing_required" -gt 0 ]; then
  exit 1
fi
exit 0
