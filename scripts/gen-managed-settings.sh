#!/usr/bin/env bash
# gen-managed-settings.sh: render .harness/constitution.json + .harness/mcp-policy.json
# into a Claude Code managed-settings JSON document (stdout, or --out PATH).
#
# Fail-closed: missing or invalid input JSON -> exit 1 with a clear error and no
# partial output (rendering goes to a temp buffer and is only emitted on success).
#
# MAPPING (mechanical mappings only; behavioral invariants are skipped):
#
#   constitution.protected_invariants -> permissions.deny:
#     "self-mod-human-review"           -> Edit(.harness/constitution.json)
#                                          Write(.harness/constitution.json)
#     "self-mod-invariant-preservation" -> Edit(.harness/manifest.json)
#                                          Write(.harness/manifest.json)
#     (all other invariants are behavioral contracts, e.g. no-ai-attribution,
#      idempotency-check, read-only-by-construction; they have no mechanical
#      permission-rule equivalent and are intentionally not mapped)
#
#   constitution.branch_policy -> permissions.deny:
#     branch marked "protected"         -> Bash(git push origin <branch>:*)
#     any protected branch present      -> Bash(git push --force:*)
#                                          Bash(git push -f:*)
#     (permission rules are prefix-based, so flag orderings other than these
#      common forms are not fully expressible; hooks remain the backstop)
#
#   constitution-protected invariants -> allowManagedPermissionRulesOnly:
#     true when protected_invariants is non-empty (invariants must not be
#     bypassable by local/user settings layers).
#
#   constitution.branch_policy -> forceRemoteSettingsRefresh:
#     true when at least one branch is "protected" (org policy must refresh
#     from the managed channel rather than trust cached local settings).
#
#   mcp-policy.approvedServers -> allowedMcpServers (verbatim).
#   mcp-policy.defaultDeny     -> allowManagedMcpServersOnly (verbatim).
#   mcp-policy.dangerousPatterns are regexes, not permission-rule syntax, so
#   they are not mapped; hooks/check-dangerous-patterns.sh enforces them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSTITUTION="$ROOT/.harness/constitution.json"
POLICY="$ROOT/.harness/mcp-policy.json"
OUT=""

usage() {
  cat >&2 <<'EOF'
usage: gen-managed-settings.sh [--constitution PATH] [--policy PATH] [--out PATH]

Renders managed-settings JSON to stdout, or to --out PATH when given.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --constitution) CONSTITUTION="${2:?--constitution requires a path}"; shift 2 ;;
    --policy)       POLICY="${2:?--policy requires a path}"; shift 2 ;;
    --out)          OUT="${2:?--out requires a path}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# --- Input validation (fail closed) ---
[[ -f "$CONSTITUTION" ]] || fail "constitution not found at $CONSTITUTION"
[[ -f "$POLICY" ]] || fail "mcp-policy not found at $POLICY"

jq -e . "$CONSTITUTION" >/dev/null 2>&1 || fail "invalid JSON in $CONSTITUTION"
jq -e . "$POLICY" >/dev/null 2>&1 || fail "invalid JSON in $POLICY"

jq -e 'type == "object" and (.protected_invariants | type == "array") and (.branch_policy | type == "object")' \
  "$CONSTITUTION" >/dev/null || fail "$CONSTITUTION: missing required keys (protected_invariants: array, branch_policy: object)"

jq -e 'type == "object" and (.approvedServers | type == "array") and (.defaultDeny | type == "boolean")' \
  "$POLICY" >/dev/null || fail "$POLICY: missing required keys (approvedServers: array, defaultDeny: boolean)"

# --- Render ---
managed_only="$(jq '(.protected_invariants | length) > 0' "$CONSTITUTION")"
force_refresh="$(jq '[.branch_policy | to_entries[] | select(.value == "protected")] | length > 0' "$CONSTITUTION")"

deny_rules="$(jq -c '
  (if (.protected_invariants | index("self-mod-human-review")) then
     ["Edit(.harness/constitution.json)", "Write(.harness/constitution.json)"] else [] end)
  + (if (.protected_invariants | index("self-mod-invariant-preservation")) then
     ["Edit(.harness/manifest.json)", "Write(.harness/manifest.json)"] else [] end)
  + ([.branch_policy | to_entries[] | select(.value == "protected") | .key]
     | map("Bash(git push origin \(.)" + ":*)"))
  + (if ([.branch_policy | to_entries[] | select(.value == "protected")] | length) > 0
     then ["Bash(git push --force:*)", "Bash(git push -f:*)"] else [] end)
' "$CONSTITUTION")"

approved_servers="$(jq -c '.approvedServers' "$POLICY")"
default_deny="$(jq '.defaultDeny' "$POLICY")"

rendered="$(jq -n \
  --argjson deny "$deny_rules" \
  --argjson approved "$approved_servers" \
  --argjson managed_only "$managed_only" \
  --argjson force_refresh "$force_refresh" \
  --argjson default_deny "$default_deny" \
  '{
    permissions: { deny: $deny },
    allowManagedPermissionRulesOnly: $managed_only,
    forceRemoteSettingsRefresh: $force_refresh,
    allowedMcpServers: $approved,
    allowManagedMcpServersOnly: $default_deny
  }')" || fail "failed to render managed-settings JSON"

# Final parse check before emitting anything.
printf '%s\n' "$rendered" | jq -e . >/dev/null 2>&1 || fail "rendered output is not valid JSON (refusing to emit)"

if [[ -n "$OUT" ]]; then
  tmp_out="$(mktemp "${OUT}.tmp.XXXXXX")"
  printf '%s\n' "$rendered" > "$tmp_out"
  mv "$tmp_out" "$OUT"
  echo "OK: managed-settings written to $OUT" >&2
else
  printf '%s\n' "$rendered"
fi
