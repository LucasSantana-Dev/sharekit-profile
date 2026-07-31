#!/usr/bin/env bats
# tests for hooks/check-ac-coverage.sh

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/accov-$$"
  mkdir -p "$TEST_TMP"
  cat > "$TEST_TMP/requirements.md" <<'EOF'
### REQ-1: login
### REQ-2: logout
EOF
}

@test "check-ac-coverage: all tasks traced passes" {
  cat > "$TEST_TMP/tasks.md" <<'EOF'
| # | Task | Requirement | Acceptance | Status |
| 1 | build form | REQ-1 | AC-1.1 | pending |
| 2 | wire logout | REQ-2 | AC-2.1 | pending |
EOF
  run bash "$REPO_ROOT/hooks/check-ac-coverage.sh" --tasks "$TEST_TMP/tasks.md" --requirements "$TEST_TMP/requirements.md"
  [ "$status" -eq 0 ]
}

@test "check-ac-coverage: untraced task fails" {
  cat > "$TEST_TMP/tasks.md" <<'EOF'
| 1 | build form | REQ-1 | AC-1.1 | pending |
| 2 | random refactor |  |  | pending |
EOF
  run bash "$REPO_ROOT/hooks/check-ac-coverage.sh" --tasks "$TEST_TMP/tasks.md" --requirements "$TEST_TMP/requirements.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNTRACED"* ]]
}

@test "check-ac-coverage: unknown requirement ID fails" {
  cat > "$TEST_TMP/tasks.md" <<'EOF'
| 1 | build form | REQ-9 | AC-9.1 | pending |
EOF
  run bash "$REPO_ROOT/hooks/check-ac-coverage.sh" --tasks "$TEST_TMP/tasks.md" --requirements "$TEST_TMP/requirements.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNKNOWN-REQ: REQ-9"* ]]
}

@test "check-ac-coverage: --spec-dir resolves template layout" {
  cp "$TEST_TMP/requirements.md" "$TEST_TMP/req-copy.md"
  mkdir -p "$TEST_TMP/spec"
  cp "$TEST_TMP/requirements.md" "$TEST_TMP/spec/requirements.md"
  cat > "$TEST_TMP/spec/tasks.md" <<'EOF'
| 1 | build form | REQ-1 | AC-1.1 | pending |
EOF
  run bash "$REPO_ROOT/hooks/check-ac-coverage.sh" --spec-dir "$TEST_TMP/spec"
  [ "$status" -eq 0 ]
}

@test "check-ac-coverage: template itself is self-consistent" {
  # The shipped _template tasks.md references REQ-1/REQ-2 which the
  # _template requirements.md declares.
  run bash "$REPO_ROOT/hooks/check-ac-coverage.sh" --spec-dir "$REPO_ROOT/specs/_template"
  [ "$status" -eq 0 ]
}
