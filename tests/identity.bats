#!/usr/bin/env bats
# tests for hooks/check-identity.sh (appended to gates.bats groups)

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/identity-$$"
  mkdir -p "$TEST_TMP"
}

mkrepo() {
  local dir="$1"
  mkdir -p "$dir/.harness"
  cd "$dir"
  git init -q
  git config user.email "someone@example.com"
  git config user.name "Test User"
}

@test "check-identity: no declaration passes through" {
  mkrepo "$TEST_TMP/no-decl"
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 0 ]
}

@test "check-identity: matching email passes" {
  mkrepo "$TEST_TMP/match"
  echo '{"email": "someone@example.com"}' > "$TEST_TMP/match/.harness/identity.json"
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 0 ]
}

@test "check-identity: mismatched email fails with guidance" {
  mkrepo "$TEST_TMP/mismatch"
  echo '{"email": "expected@corp.com"}' > "$TEST_TMP/mismatch/.harness/identity.json"
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"expected@corp.com"* ]]
}

@test "check-identity: emails array membership" {
  mkrepo "$TEST_TMP/multi"
  echo '{"emails": ["a@corp.com", "someone@example.com"]}' > "$TEST_TMP/multi/.harness/identity.json"
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 0 ]
}

@test "check-identity: emails array rejects non-member" {
  mkrepo "$TEST_TMP/multi-bad"
  echo '{"emails": ["a@corp.com", "b@corp.com"]}' > "$TEST_TMP/multi-bad/.harness/identity.json"
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 1 ]
}

@test "check-identity: operators.json passes any operator email" {
  mkrepo "$TEST_TMP/ops"
  cat > "$TEST_TMP/ops/.harness/operators.json" <<'EOF'
{"operators": [{"name": "A", "emails": ["someone@example.com"], "role": "owner"},
               {"name": "B", "emails": ["b@corp.com"], "role": "member"}]}
EOF
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 0 ]
}

@test "check-identity: operators.json rejects unknown email" {
  mkrepo "$TEST_TMP/ops-bad"
  cat > "$TEST_TMP/ops-bad/.harness/operators.json" <<'EOF'
{"operators": [{"name": "A", "emails": ["a@corp.com"], "role": "owner"}]}
EOF
  run bash "$REPO_ROOT/hooks/check-identity.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"operators.json"* ]]
}
