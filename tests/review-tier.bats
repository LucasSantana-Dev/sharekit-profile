#!/usr/bin/env bats
# tests/review-tier.bats - fixture-diff classification tests for
# scripts/review-tier.sh (spec D2 tiering, D4 noise pre-filter).

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/review-tier.sh"
  export FIXTURES="$REPO_ROOT/tests/fixtures/review-tier"
  export TEST_TMP="$BATS_TEST_TMPDIR/review-tier-$$"
  export REVIEW_CONTEXT_DIR="$TEST_TMP/review-context"
  mkdir -p "$TEST_TMP"
}

teardown() {
  if [[ -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP" 2>/dev/null || true
  fi
}

# A 150-line diff overall whose changed (+/-) lines total 100 (80 add, 20 del),
# the rest being headers and context: exercises the LITE_MAX_LINES=100 boundary.
mk_lite_patch() { # $1 = output file
  {
    echo "diff --git a/src/feature.ts b/src/feature.ts"
    echo "index 1111111..2222222 100644"
    echo "--- a/src/feature.ts"
    echo "+++ b/src/feature.ts"
    echo "@@ -1,65 +1,125 @@"
    for i in $(seq 1 20); do echo "-old line $i"; done
    for i in $(seq 1 80); do echo "+new line $i"; done
    for i in $(seq 1 45); do echo " context line $i"; done
  } > "$1"
}

@test "10-line docs change is trivial with downgraded coordinator" {
  run bash "$SCRIPT" < "$FIXTURES/docs-trivial.patch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=trivial"* ]]
  [[ "$output" == *"coordinator_downgraded=true"* ]]
  [[ "$output" == *"coordinator_model=anthropic/claude-sonnet-4-5"* ]]
  [[ "$output" == *"reviewers=general"$'\n'* || "$output" == *"reviewers=general" ]]
  [[ "$output" == *"lines=10"* ]]
}

@test "150-line diff (100 changed lines) is lite" {
  mk_lite_patch "$TEST_TMP/lite.patch"
  run bash "$SCRIPT" < "$TEST_TMP/lite.patch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=lite"* ]]
  [[ "$output" == *"lines=100"* ]]
  [[ "$output" == *"coordinator_downgraded=false"* ]]
  [[ "$output" == *"coordinator_model=anthropic/claude-opus-4-8"* ]]
  [[ "$output" == *"reviewers=general,security,docs"* ]]
}

@test "60-file diff is full regardless of line count" {
  for i in $(seq 1 60); do printf '1\t0\tsrc/f%d.ts\n' "$i"; done > "$TEST_TMP/60files.numstat"
  run bash "$SCRIPT" < "$TEST_TMP/60files.numstat"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=full"* ]]
  [[ "$output" == *"files=60"* ]]
  [[ "$output" == *"reviewers=general,security,quality,docs"* ]]
}

@test "src/auth path forces full review regardless of size" {
  run bash "$SCRIPT" < "$FIXTURES/auth-small.patch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=full"* ]]
  [[ "$output" == *"lines=3"* ]]
  [[ "$output" == *"coordinator_downgraded=false"* ]]
}

@test "lockfile-only diff yields zero reviewable files in context" {
  run bash "$SCRIPT" < "$FIXTURES/lockfile-only.patch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reviewable_files=0"* ]]
  [ -f "$REVIEW_CONTEXT_DIR/context.txt" ]
  [ -d "$REVIEW_CONTEXT_DIR/files" ]
  count=$(find "$REVIEW_CONTEXT_DIR/files" -type f | wc -l | tr -d ' ')
  [ "$count" = "0" ]
}

@test "review-context keeps per-file patches and shared context file" {
  run bash "$SCRIPT" < "$FIXTURES/auth-small.patch"
  [ "$status" -eq 0 ]
  [ -f "$REVIEW_CONTEXT_DIR/files/src_auth_login.ts.patch" ]
  [ -f "$REVIEW_CONTEXT_DIR/context.txt" ]
  grep -q "tier=full" "$REVIEW_CONTEXT_DIR/context.txt"
  grep -q "src/auth/login.ts" "$REVIEW_CONTEXT_DIR/context.txt"
}

@test "migration files survive the noise pre-filter" {
  {
    echo "diff --git a/db/migrations/0001_init.sql b/db/migrations/0001_init.sql"
    echo "index 1111111..2222222 100644"
    echo "--- a/db/migrations/0001_init.sql"
    echo "+++ b/db/migrations/0001_init.sql"
    echo "@@ -0,0 +1,2 @@"
    echo "+CREATE TABLE users (id int);"
    echo "+CREATE TABLE posts (id int);"
    echo "diff --git a/assets/app.min.js b/assets/app.min.js"
    echo "index 3333333..4444444 100644"
    echo "--- a/assets/app.min.js"
    echo "+++ b/assets/app.min.js"
    echo "@@ -1 +1 @@"
    echo "-old minified"
    echo "+new minified"
  } > "$TEST_TMP/mixed.patch"
  run bash "$SCRIPT" < "$TEST_TMP/mixed.patch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reviewable_files=1"* ]]
  [ -f "$REVIEW_CONTEXT_DIR/files/db_migrations_0001_init.sql.patch" ]
}
