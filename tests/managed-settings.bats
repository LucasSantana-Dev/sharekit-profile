#!/usr/bin/env bats
# tests/managed-settings.bats - Test suite for scripts/gen-managed-settings.sh
# Hermetic: uses fixture JSON in BATS_TEST_TMPDIR, never the real .harness files.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/test-$$"
  mkdir -p "$TEST_TMP"

  cat > "$TEST_TMP/constitution.json" <<'EOF'
{
  "schema": "harness-constitution/v1",
  "protected_invariants": [
    "no-ai-attribution",
    "self-mod-human-review",
    "self-mod-invariant-preservation"
  ],
  "branch_policy": {
    "main": "protected",
    "feature": "pr-required"
  }
}
EOF

  cat > "$TEST_TMP/mcp-policy.json" <<'EOF'
{
  "policy_version": "1.0",
  "defaultDeny": true,
  "dangerousPatterns": ["rm\\s+-rf"],
  "approvedServers": ["rag-index", "git", "fetch"]
}
EOF
}

teardown() {
  if [[ -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP" 2>/dev/null || true
  fi
}

@test "gen-managed-settings: valid inputs produce parseable JSON with expected keys" {
  run bash "$REPO_ROOT/scripts/gen-managed-settings.sh" \
    --constitution "$TEST_TMP/constitution.json" \
    --policy "$TEST_TMP/mcp-policy.json"
  [ "$status" -eq 0 ]

  # stdout must be valid JSON with the managed-settings keys
  printf '%s' "$output" | jq -e '
    (.permissions.deny | type == "array") and
    (.allowManagedPermissionRulesOnly | type == "boolean") and
    (.forceRemoteSettingsRefresh | type == "boolean") and
    (.allowedMcpServers | type == "array") and
    (.allowManagedMcpServersOnly | type == "boolean")
  ' >/dev/null

  # values derived from the fixtures
  printf '%s' "$output" | jq -e '
    .allowManagedPermissionRulesOnly == true and
    .forceRemoteSettingsRefresh == true and
    .allowedMcpServers == ["rag-index", "git", "fetch"] and
    .allowManagedMcpServersOnly == true
  ' >/dev/null
}

@test "gen-managed-settings: missing constitution.json exits nonzero with no output" {
  run bash "$REPO_ROOT/scripts/gen-managed-settings.sh" \
    --constitution "$TEST_TMP/does-not-exist.json" \
    --policy "$TEST_TMP/mcp-policy.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"permissions"* ]]
}

@test "gen-managed-settings: corrupted mcp-policy.json exits nonzero with no output" {
  printf '{not valid json' > "$TEST_TMP/mcp-policy.json"
  run bash "$REPO_ROOT/scripts/gen-managed-settings.sh" \
    --constitution "$TEST_TMP/constitution.json" \
    --policy "$TEST_TMP/mcp-policy.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"permissions"* ]]
}

@test "gen-managed-settings: deny rules are derived from fixture invariants and branch policy" {
  run bash "$REPO_ROOT/scripts/gen-managed-settings.sh" \
    --constitution "$TEST_TMP/constitution.json" \
    --policy "$TEST_TMP/mcp-policy.json"
  [ "$status" -eq 0 ]

  # self-mod invariants -> Edit/Write deny on harness policy files
  printf '%s' "$output" | jq -e '
    (.permissions.deny | index("Edit(.harness/constitution.json)")) and
    (.permissions.deny | index("Write(.harness/constitution.json)")) and
    (.permissions.deny | index("Edit(.harness/manifest.json)")) and
    (.permissions.deny | index("Write(.harness/manifest.json)"))
  ' >/dev/null

  # protected branch -> push denies; non-protected branch absent
  printf '%s' "$output" | jq -e '
    (.permissions.deny | index("Bash(git push origin main:*)")) and
    (.permissions.deny | index("Bash(git push --force:*)")) and
    ((.permissions.deny | index("Bash(git push origin feature:*)")) | not)
  ' >/dev/null
}

@test "gen-managed-settings: --out writes parseable file, stdout stays clean" {
  run bash "$REPO_ROOT/scripts/gen-managed-settings.sh" \
    --constitution "$TEST_TMP/constitution.json" \
    --policy "$TEST_TMP/mcp-policy.json" \
    --out "$TEST_TMP/managed-settings.json"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/managed-settings.json" ]
  jq -e '.permissions.deny | type == "array"' "$TEST_TMP/managed-settings.json" >/dev/null
}
