#!/usr/bin/env bats
# tests for scripts/scan-transcripts.sh (gitleaks over session transcripts)
# Fixtures are generated into the test tmpdir: no synthetic token ever lives in
# the repo, so the repo-wide gitleaks CI job stays green without allowlisting.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/scan-$$"
  mkdir -p "$TEST_TMP/leaky" "$TEST_TMP/clean"
  if ! command -v gitleaks >/dev/null 2>&1; then
    skip "gitleaks not installed"
  fi
}

@test "scan-transcripts: detects planted synthetic token in transcript" {
  # Token assembled at runtime so the repo-wide gitleaks CI job does not
  # flag this test file (no literal secret-shaped string in the repo).
  local token="ghp_""SyntheticTestToken0123456789abcdEFGH"
  printf '%s\n' "{\"type\":\"user\",\"message\":{\"content\":\"deploy this with token ${token}\"}}" \
    > "$TEST_TMP/leaky/session.jsonl"
  run bash "$REPO_ROOT/scripts/scan-transcripts.sh" "$TEST_TMP/leaky"
  [ "$status" -eq 1 ]
}

@test "scan-transcripts: clean transcript passes" {
  cat > "$TEST_TMP/clean/session.jsonl" <<'EOF'
{"type":"user","message":{"content":"refactor the parser"}}
EOF
  run bash "$REPO_ROOT/scripts/scan-transcripts.sh" "$TEST_TMP/clean"
  [ "$status" -eq 0 ]
}

@test "scan-transcripts: missing target dir skips gracefully" {
  run bash "$REPO_ROOT/scripts/scan-transcripts.sh" "$TEST_TMP/does-not-exist"
  [ "$status" -eq 0 ]
}
