#!/usr/bin/env bats
# tests for hooks/memory-scope-gate.sh + .harness/memory-scopes.json

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/memscope-$$"
  mkdir -p "$TEST_TMP/repo/.harness"
  cd "$TEST_TMP/repo"
  git init -q
  git config user.email "userA@example.com"
  git config user.name "User A"
  cp "$REPO_ROOT/.harness/memory-scopes.json" .harness/
}

gate() {  # gate <tool> <path> <content>
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2" "$3" \
    | bash "$REPO_ROOT/hooks/memory-scope-gate.sh"
}

@test "memory-scope-gate: no policy file fails open" {
  rm .harness/memory-scopes.json
  run gate Write "$TEST_TMP/repo/.agents/memory/note.md" "hello"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: non-memory tool passes" {
  run gate Bash "n/a" "ls -la"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: personal-scope write allowed" {
  run gate Write "$TEST_TMP/repo/.claude/projects/x/memory/note.md" "session learning"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: team-scope write without private tags allowed" {
  run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "curated team learning"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: CROSS-USER LEAK - private-tagged note blocked from team scope" {
  # User A's private-tagged session note must never reach the team-scope file
  # that user B's context injection reads.
  run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "salary talk <private>do not share</private>"
  [ "$status" -eq 2 ]
  [[ "$output" == *"never promotes"* ]]
}

@test "memory-scope-gate: content referencing personal memory path blocked from team scope" {
  run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "see /Users/b/.claude/projects/x/memory/secret.md"
  [ "$status" -eq 2 ]
}

@test "memory-scope-gate: policy schema declares 3 scopes with defaultDeny" {
  run jq -r '.defaultDeny, (.scopes | keys | join(","))' "$REPO_ROOT/.harness/memory-scopes.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"true"* ]]
  [[ "$output" == *"org,personal,team"* ]]
}
