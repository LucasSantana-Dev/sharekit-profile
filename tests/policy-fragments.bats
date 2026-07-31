#!/usr/bin/env bats
# tests for scripts/merge-policy-fragments.sh (.harness/policy.d drop-in merge)

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/policy-d-$$"
  mkdir -p "$TEST_TMP"
}

mkfrag() {
  # mkfrag <dir> <name> <json>
  mkdir -p "$1"
  printf '%s\n' "$3" > "$1/$2"
}

@test "merge: no policy.d directory outputs empty object" {
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$TEST_TMP/does-not-exist"
  [ "$status" -eq 0 ]
  [ "$output" = '{}' ]
}

@test "merge: empty policy.d outputs empty object" {
  mkdir -p "$TEST_TMP/empty"
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$TEST_TMP/empty"
  [ "$status" -eq 0 ]
  [ "$output" = '{}' ]
}

@test "merge: deterministic numeric-prefix order, higher prefix wins scalar conflicts" {
  local d="$TEST_TMP/order"
  mkfrag "$d" 10-base.json '{"level": "base", "shared": "from-10", "keep": true}'
  mkfrag "$d" 20-override.json '{"level": "override", "shared": "from-20"}'
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.level')" = "override" ]
  [ "$(printf '%s' "$output" | jq -r '.shared')" = "from-20" ]
  [ "$(printf '%s' "$output" | jq -r '.keep')" = "true" ]
}

@test "merge: order is filename sort, not filesystem order" {
  local d="$TEST_TMP/sort"
  # Create the higher-prefix file first so inode/creation order disagrees.
  mkfrag "$d" 90-late.json '{"winner": "ninety"}'
  mkfrag "$d" 05-early.json '{"winner": "five"}'
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.winner')" = "ninety" ]
}

@test "merge: deny arrays union and dedupe across fragments" {
  local d="$TEST_TMP/union"
  mkfrag "$d" 10-a.json '{"deny": ["x", "y"]}'
  mkfrag "$d" 20-b.json '{"deny": ["y", "z"]}'
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -c '.deny')" = '["x","y","z"]' ]
}

@test "merge: nested objects merge recursively" {
  local d="$TEST_TMP/nested"
  mkfrag "$d" 10-a.json '{"limits": {"cpu": 2, "mem": 512}}'
  mkfrag "$d" 20-b.json '{"limits": {"mem": 1024}}'
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.limits.cpu')" = "2" ]
  [ "$(printf '%s' "$output" | jq -r '.limits.mem')" = "1024" ]
}

@test "merge: invalid JSON fragment fails closed" {
  local d="$TEST_TMP/invalid"
  mkfrag "$d" 10-good.json '{"ok": true}'
  printf '{not json\n' > "$d/20-broken.json"
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$d"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid policy fragment"* ]]
}

@test "merge: non-object fragment fails closed" {
  local d="$TEST_TMP/nonobj"
  mkfrag "$d" 10-arr.json '["not", "an", "object"]'
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh" "$d"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid policy fragment"* ]]
}

@test "merge: repo example fragments produce expected effective policy" {
  run bash "$REPO_ROOT/scripts/merge-policy-fragments.sh"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.defaultDeny')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r '.allowNetwork')" = "false" ]
  [ "$(printf '%s' "$output" | jq -r '.maxToolCallsPerTurn')" = "25" ]
  [ "$(printf '%s' "$output" | jq -c '.dangerousPatterns')" = '["chmod 777","curl .* \\| sh","git push --force","rm -rf /"]' ]
}

@test "check-harness-manifest: tolerates unfingerprinted policy.d fragments" {
  run bash "$REPO_ROOT/scripts/check-harness-manifest.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not yet fingerprinted"* ]]
}
