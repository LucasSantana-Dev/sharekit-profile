#!/usr/bin/env bats
# tests for hooks/check-spec-drift.sh and hooks/check-config-size.sh

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/p67-$BATS_TEST_NUMBER"
  mkdir -p "$TEST_TMP/repo"
  cd "$TEST_TMP/repo"
  git init -q
  git config user.email "dev@corp.com"
  git config user.name "Dev"
}

# --- spec-drift ---

@test "check-spec-drift: requirements change without tasks change fails" {
  mkdir -p specs/feat-x
  cp "$REPO_ROOT/specs/_template/requirements.md" specs/feat-x/
  cp "$REPO_ROOT/specs/_template/tasks.md" specs/feat-x/
  git add . && git commit -qm init
  echo "### REQ-3: new thing" >> specs/feat-x/requirements.md
  git add specs/feat-x/requirements.md
  run bash "$REPO_ROOT/hooks/check-spec-drift.sh" --staged
  [ "$status" -eq 1 ]
  [[ "$output" == *"SPEC-DRIFT"* ]]
}

@test "check-spec-drift: requirements+tasks changed together passes" {
  mkdir -p specs/feat-x
  cp "$REPO_ROOT/specs/_template/requirements.md" specs/feat-x/
  cp "$REPO_ROOT/specs/_template/tasks.md" specs/feat-x/
  git add . && git commit -qm init
  echo "### REQ-3: new thing" >> specs/feat-x/requirements.md
  echo "| 4 | build it | REQ-3 | AC-3.1 | pending |" >> specs/feat-x/tasks.md
  git add specs/
  run bash "$REPO_ROOT/hooks/check-spec-drift.sh" --staged
  [ "$status" -eq 0 ]
}

@test "check-spec-drift: no spec files at all passes" {
  echo "x" > code.py
  git add code.py
  run bash "$REPO_ROOT/hooks/check-spec-drift.sh" --staged
  [ "$status" -eq 0 ]
}

@test "check-spec-drift: code change with feature specs warns but passes" {
  mkdir -p specs/feat-y
  cp "$REPO_ROOT/specs/_template/requirements.md" specs/feat-y/
  git add . && git commit -qm init
  echo "print(1)" > app.py
  git add app.py
  run bash "$REPO_ROOT/hooks/check-spec-drift.sh" --staged
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}

# --- config-size ---

@test "check-config-size: small CLAUDE.md passes" {
  echo "# hi" > CLAUDE.md
  run bash "$REPO_ROOT/hooks/check-config-size.sh"
  [ "$status" -eq 0 ]
}

@test "check-config-size: >400 warns, passes" {
  for i in $(seq 1 450); do echo "line $i"; done > CLAUDE.md
  run bash "$REPO_ROOT/hooks/check-config-size.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}

@test "check-config-size: >800 fails" {
  for i in $(seq 1 850); do echo "line $i"; done > AGENTS.md
  run bash "$REPO_ROOT/hooks/check-config-size.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"AGENTS.md has 850 lines"* ]]
}

@test "check-config-size: local settings divergence warns" {
  mkdir -p .claude
  echo '{"model": "sonnet", "theme": "dark"}' > .claude/settings.json
  echo '{"model": "opus"}' > .claude/settings.local.json
  run bash "$REPO_ROOT/hooks/check-config-size.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"model"* ]]
}

@test "check-config-size: local settings in agreement is quiet" {
  mkdir -p .claude
  echo '{"model": "sonnet"}' > .claude/settings.json
  echo '{"model": "sonnet", "extra": true}' > .claude/settings.local.json
  run bash "$REPO_ROOT/hooks/check-config-size.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"diverges"* ]]
}
