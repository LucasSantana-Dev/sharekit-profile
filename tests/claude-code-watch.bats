#!/usr/bin/env bats
# tests/claude-code-watch.bats - scripts/claude-code-changelog-watch.sh, offline

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export FIX="$BATS_TEST_TMPDIR/CHANGELOG.md"
  reviewed="$(tr -d '[:space:]' < "$REPO_ROOT/.harness/claude-code-reviewed")"
  cat > "$FIX" <<MD
# Changelog

## 9.9.9

- Added a new hook event for skills
- Fixed a typo in the welcome screen

## $reviewed

- Added a plugin field that was already reviewed
MD
}

@test "changelog watch: reports only harness lines from newer releases" {
  run bash "$REPO_ROOT/scripts/claude-code-changelog-watch.sh" "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"### 9.9.9"* ]]
  [[ "$output" == *"new hook event"* ]]
  [[ "$output" != *"welcome screen"* ]]
  [[ "$output" != *"already reviewed"* ]]
}

@test "changelog watch: prints nothing when no release is newer" {
  printf '# Changelog\n\n## 0.0.1\n\n- Added a hook\n' > "$FIX"
  run bash "$REPO_ROOT/scripts/claude-code-changelog-watch.sh" "$FIX"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
