#!/usr/bin/env bats
# tests for scripts/review-state.sh (spec D5: incremental re-review state)

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "review-state: gh failure degrades to empty state, exit 0" {
  gh() { return 1; }
  export -f gh
  run bash "$REPO_ROOT/scripts/review-state.sh" 123
  [ "$status" -eq 0 ]
  [[ "$output" == *'"previous_review": ""'* ]]
  [[ "$output" == *'"fingerprints": []'* ]]
}

@test "review-state: extracts prior summary + fingerprint block" {
  gh() {
    cat <<'JSON'
[{"user":{"login":"github-actions[bot]"},"body":"2 findings: 1 critical, 1 warning\n\n<!-- review-state: {\"findings\": [{\"fingerprint\": \"aaa\", \"status\": \"unfixed\"}, {\"fingerprint\": \"bbb\", \"status\": \"fixed\"}]} -->"}]
JSON
  }
  export -f gh
  run bash "$REPO_ROOT/scripts/review-state.sh" 123
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 findings: 1 critical"* ]]
  [[ "$output" == *"aaa"* ]]
  [[ "$output" == *"bbb"* ]]
  [[ "$output" != *"review-state:"* || "$output" == *"previous_review"* ]]
}

@test "review-state: no prior bot review means empty state" {
  gh() { echo '[{"user":{"login":"human-reviewer"},"body":"looks fine"}]'; }
  export -f gh
  run bash "$REPO_ROOT/scripts/review-state.sh" 123
  [ "$status" -eq 0 ]
  [[ "$output" == *'"previous_review": ""'* ]]
}
