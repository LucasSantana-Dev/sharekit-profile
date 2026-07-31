#!/usr/bin/env bats
# tests for scripts/team-memory-sync.sh — end-to-end with a local bare vault.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/vault-$$"
  mkdir -p "$TEST_TMP"

  # Bare vault remote + two consuming clones (two developers).
  git init -q --bare "$TEST_TMP/vault.git"
  for side in a b; do
    mkdir -p "$TEST_TMP/$side/.harness"
    cd "$TEST_TMP/$side"
    git init -q
    git config user.email "dev$side@corp.com"
    git config user.name "Dev $side"
    cat > .harness/team-vault.json <<EOF
{"repo": "$TEST_TMP/vault.git", "dir": ".agents/memory/.vault", "branch": "main", "notes_subdir": "notes"}
EOF
    # Consuming repos install the profile, which carries the scope policy.
    cp "$REPO_ROOT/.harness/memory-scopes.json" .harness/
  done
  # Seed the vault's main branch (empty repos have no main to clone).
  git -C "$TEST_TMP" init -q seed
  cd "$TEST_TMP/seed"
  git config user.email seed@corp.com
  git config user.name Seed
  git checkout -q -b main
  mkdir -p notes
  echo "# team vault" > notes/README.md
  git add . && git commit -qm init
  git push -q "$TEST_TMP/vault.git" main
}

@test "team-memory-sync: missing config fails closed" {
  cd "$TEST_TMP/seed"
  rm -f .harness/team-vault.json 2>/dev/null || true
  mkdir -p emptyrepo && cd emptyrepo && git init -q
  run bash "$REPO_ROOT/scripts/team-memory-sync.sh" pull
  [ "$status" -eq 2 ]
  [[ "$output" == *"team-vault.json"* ]]
}

@test "team-memory-sync: end-to-end - dev A pushes, dev B pulls" {
  cd "$TEST_TMP/a"
  echo "# learned: routing gate skips unlisted skills" > proposal.md
  run bash "$REPO_ROOT/scripts/team-memory-sync.sh" push proposal.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"pushed proposal.md"* ]]

  cd "$TEST_TMP/b"
  run bash "$REPO_ROOT/scripts/team-memory-sync.sh" pull
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/b/.agents/memory/team/proposal.md" ]
  grep -q "routing gate" "$TEST_TMP/b/.agents/memory/team/proposal.md"
}

@test "team-memory-sync: private-tagged note refused at transport" {
  cd "$TEST_TMP/a"
  echo "secret <private>never share</private>" > private-note.md
  run bash "$REPO_ROOT/scripts/team-memory-sync.sh" push private-note.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"never promotes"* ]]
}

@test "team-memory-sync: identical re-push is idempotent" {
  cd "$TEST_TMP/a"
  echo "# same note" > same.md
  bash "$REPO_ROOT/scripts/team-memory-sync.sh" push same.md >/dev/null
  run bash "$REPO_ROOT/scripts/team-memory-sync.sh" push same.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"already done - skipping"* ]]
}

@test "team-memory-sync: scope gate + transport agree (belt and suspenders)" {
  # The hook blocks private content at write time; the transport blocks it at
  # push time. Both must fire on the same payload class.
  cd "$TEST_TMP/a"
  echo "x <private>y</private>" > gated.md
  run bash "$REPO_ROOT/scripts/team-memory-sync.sh" push gated.md
  [ "$status" -eq 1 ]
  run bash -c "cd '$TEST_TMP/a' && printf '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEST_TMP/a/.agents/memory/shared.md\",\"content\":\"x <private>y</private>\"}}' | bash '$REPO_ROOT/hooks/memory-scope-gate.sh'"
  [ "$status" -eq 2 ]
}
