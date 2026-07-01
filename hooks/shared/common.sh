#!/usr/bin/env bash
# hooks/shared/common.sh — shared utilities for hook scripts.
# Source this file near the top of a hook script (after `set -uo pipefail`) to get:
#   - ROOT, RUNTIME, FORGE path variables
#   - read_hook_stdin() to read stdin once into HOOK_INPUT
#   - hook_field() to extract jq paths from JSON
#
# Usage:
#   set -uo pipefail
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared/common.sh"
#   read_hook_stdin
#   tool_name="$(hook_field "$HOOK_INPUT" ".tool_name")"

set -uo pipefail

# ---- Path derivation (sourced into caller's scope) ---
# Each hook that sources this will get these as variables in its own scope.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"

# ---- Read stdin once and store in HOOK_INPUT ----
# After calling this, use $HOOK_INPUT to reference the input instead of
# re-reading stdin (which is impossible after the first read).
read_hook_stdin() {
  HOOK_INPUT="$(sed -n '1,$p')"
}

# ---- Extract a single string field from JSON ----
# Usage: hook_field "$HOOK_INPUT" ".tool_name"
# Returns: the field value, or empty string if not found / jq fails
hook_field() {
  local json="$1"
  local path="$2"
  printf '%s' "$json" | jq -r "$path // empty" 2>/dev/null || true
}

# ---- Extract as raw JSON (compact) ----
# Usage: hook_field_json "$HOOK_INPUT" ".tool_input"
# Returns: the field as compact JSON, or 'null' if not found / jq fails
hook_field_json() {
  local json="$1"
  local path="$2"
  printf '%s' "$json" | jq -c "$path // empty" 2>/dev/null || echo 'null'
}
