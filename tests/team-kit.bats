#!/usr/bin/env bats
# tests for scripts/bootstrap-team.sh and scripts/repo-mode.sh

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/teamkit-$$"
  mkdir -p "$TEST_TMP/repo"
  cd "$TEST_TMP/repo"
  git init -q
  git config user.email "dev@corp.com"
  git config user.name "Dev One"
}

@test "bootstrap-team: --dry-run writes nothing" {
  run bash "$REPO_ROOT/scripts/bootstrap-team.sh" --target "$TEST_TMP/repo" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_TMP/repo/.harness/operators.json" ]
  [ ! -f "$TEST_TMP/repo/.agents/mode" ]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "bootstrap-team: creates operators.json, settings stub, mode marker" {
  run bash "$REPO_ROOT/scripts/bootstrap-team.sh" --target "$TEST_TMP/repo"
  [ "$status" -eq 0 ]
  jq -e '.operators[0].emails[0] == "dev@corp.com"' "$TEST_TMP/repo/.harness/operators.json"
  jq -e '.permissions' "$TEST_TMP/repo/.claude/settings.json"
  [ "$(cat "$TEST_TMP/repo/.agents/mode")" = "cooperative" ]
}

@test "bootstrap-team: idempotent second run skips existing files" {
  bash "$REPO_ROOT/scripts/bootstrap-team.sh" --target "$TEST_TMP/repo" >/dev/null
  run bash "$REPO_ROOT/scripts/bootstrap-team.sh" --target "$TEST_TMP/repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already done - skipping"* ]]
}

@test "repo-mode: explicit marker wins" {
  echo "cooperative" > "$TEST_TMP/repo/.agents_mode_tmp" 2>/dev/null || true
  mkdir -p "$TEST_TMP/repo/.agents"
  echo "cooperative" > "$TEST_TMP/repo/.agents/mode"
  [ "$(bash "$REPO_ROOT/scripts/repo-mode.sh" "$TEST_TMP/repo")" = "cooperative" ]
  echo "solo" > "$TEST_TMP/repo/.agents/mode"
  [ "$(bash "$REPO_ROOT/scripts/repo-mode.sh" "$TEST_TMP/repo")" = "solo" ]
}

@test "repo-mode: no remote and no marker means solo" {
  [ "$(bash "$REPO_ROOT/scripts/repo-mode.sh" "$TEST_TMP/repo")" = "solo" ]
}

@test "repo-mode: unknown org remote defaults to cooperative" {
  git remote add origin "git@github.com:some-corp/team-repo.git"
  [ "$(bash "$REPO_ROOT/scripts/repo-mode.sh" "$TEST_TMP/repo")" = "cooperative" ]
}

@test "repo-mode: operators.json github handle makes own remote solo" {
  git remote add origin "git@github.com:dev-one/team-repo.git"
  mkdir -p "$TEST_TMP/repo/.harness"
  cat > "$TEST_TMP/repo/.harness/operators.json" <<'EOF'
{"operators": [{"name": "Dev One", "github": "dev-one", "emails": ["dev@corp.com"], "role": "owner"}]}
EOF
  [ "$(bash "$REPO_ROOT/scripts/repo-mode.sh" "$TEST_TMP/repo")" = "solo" ]
}
