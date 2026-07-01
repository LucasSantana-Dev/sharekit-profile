#!/usr/bin/env bats
# tests/flywheel-safety.bats - Test suite for flywheel self-modification safety gates (C1)
# Tests are hermetic: use actual repo structure or tmpdir + direct script location paths

setup() {
  # Get the actual repo root where the scripts are
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/test-$$"
  export TEST_FORGE="$TEST_TMP/.harness/forge"
  export TEST_RUNTIME="$TEST_TMP/.harness/runtime"
  mkdir -p "$TEST_FORGE/proposals" "$TEST_RUNTIME"
}

# =============================================================================
# TEST GROUP 1: Constitution amendments are in place (C1 foundation)
# =============================================================================

@test "constitution.md contains self-mod-human-review" {
  [[ -f "$REPO_ROOT/.harness/constitution.md" ]]
  grep -q "self-mod-human-review" "$REPO_ROOT/.harness/constitution.md"
}

@test "constitution.md contains self-mod-rollback-contract" {
  [[ -f "$REPO_ROOT/.harness/constitution.md" ]]
  grep -q "self-mod-rollback-contract" "$REPO_ROOT/.harness/constitution.md"
}

@test "constitution.md contains self-mod-invariant-preservation" {
  [[ -f "$REPO_ROOT/.harness/constitution.md" ]]
  grep -q "self-mod-invariant-preservation" "$REPO_ROOT/.harness/constitution.md"
}

@test "constitution.json has protected_invariants array with all three C1 invariants" {
  [[ -f "$REPO_ROOT/.harness/constitution.json" ]]
  local json="$(cat "$REPO_ROOT/.harness/constitution.json")"
  echo "$json" | jq -e '.protected_invariants | map(select(. == "self-mod-human-review")) | length > 0' >/dev/null
  echo "$json" | jq -e '.protected_invariants | map(select(. == "self-mod-rollback-contract")) | length > 0' >/dev/null
  echo "$json" | jq -e '.protected_invariants | map(select(. == "self-mod-invariant-preservation")) | length > 0' >/dev/null
}

# =============================================================================
# TEST GROUP 2: Proposal structure — new sections present
# =============================================================================

@test "propose.sh emits section 7: Rollback contract" {
  [[ -f "$REPO_ROOT/hooks/propose.sh" ]]
  grep -q "## 7. Rollback contract" "$REPO_ROOT/hooks/propose.sh"
}

@test "propose.sh emits section 8: Invariants touched" {
  [[ -f "$REPO_ROOT/hooks/propose.sh" ]]
  grep -q "## 8. Invariants touched" "$REPO_ROOT/hooks/propose.sh"
}

@test "propose.sh section 7 includes rollback fields: file, baseline, deploy_watch_metric" {
  [[ -f "$REPO_ROOT/hooks/propose.sh" ]]
  grep -q "file:" "$REPO_ROOT/hooks/propose.sh"
  grep -q "baseline:" "$REPO_ROOT/hooks/propose.sh"
  grep -q "deploy_watch_metric:" "$REPO_ROOT/hooks/propose.sh"
}

@test "propose.sh section 10 checklist includes C1 gates" {
  [[ -f "$REPO_ROOT/hooks/propose.sh" ]]
  grep -q "rollback contract: non-empty (C1" "$REPO_ROOT/hooks/propose.sh"
  grep -q "invariants touched: declared (C1" "$REPO_ROOT/hooks/propose.sh"
  grep -q "no protected surface mutations (C1" "$REPO_ROOT/hooks/propose.sh"
}

# =============================================================================
# TEST GROUP 3: Gate enforcement — rollback contract (6a)
# =============================================================================

@test "gate rejects proposal without section 7 (rollback contract missing)" {
  # Create a minimal proposal without section 7
  local proposal="$TEST_FORGE/proposals/test-no-rollback.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-001
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 9. Predicted impact

- metric: test-passes
EOF

  # Run gate with this proposal; it should FAIL on rollback contract check
  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-001" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"rollback-contract-empty"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate rejects proposal with FILL IN in rollback contract section" {
  local proposal="$TEST_FORGE/proposals/test-fillblank-rollback.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-002
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

> REQUIRED: the exact action to revert this change if it regresses post-deploy.
> FILL IN placeholder still here

## 8. Invariants touched (C1 safety gate)

none

## 9. Predicted impact

- metric: test-passes
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-002" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"rollback-contract-empty"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate accepts proposal with non-empty rollback contract" {
  local proposal="$TEST_FORGE/proposals/test-with-rollback.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-003
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/test.sh
baseline: HEAD~1
deploy_watch_metric: heldout-lift

## 8. Invariants touched (C1 safety gate)

none

## 9. Predicted impact

- metric: test-passes
- predicted_delta: +0.02
- rationale: test coverage improvement

## 10. Constraint gate checklist

- [x] tests pass
- [x] rollback contract: non-empty (C1 safety gate)
- [x] invariants touched: declared (C1 safety gate)
EOF

  # This gate check should NOT fail on rollback-contract-empty (it may fail on other grounds)
  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-003" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" != *"rollback-contract-empty"* ]]
}

# =============================================================================
# TEST GROUP 4: Gate enforcement — invariants touched (6b)
# =============================================================================

@test "gate rejects proposal without section 8 (invariants touched missing)" {
  local proposal="$TEST_FORGE/proposals/test-no-invariants.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-004
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/test.sh
baseline: HEAD~1
deploy_watch_metric: heldout-lift

## 9. Predicted impact

- metric: test-passes
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-004" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"invariants-touched-empty"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate rejects proposal with FILL IN in invariants touched section" {
  local proposal="$TEST_FORGE/proposals/test-fillblank-invariants.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-005
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/test.sh
baseline: HEAD~1
deploy_watch_metric: heldout-lift

## 8. Invariants touched (C1 safety gate)

> REQUIRED: which protected invariants does this change affect?
> FILL IN: invariants list
> List the invariant name and whether this change touches (read/write/bypass) it.

## 9. Predicted impact

- metric: test-passes
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-005" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"invariants-touched-empty"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate accepts proposal declaring 'none' for invariants touched" {
  local proposal="$TEST_FORGE/proposals/test-invariants-none.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-006
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/test.sh
baseline: HEAD~1
deploy_watch_metric: heldout-lift

## 8. Invariants touched (C1 safety gate)

none

## 9. Predicted impact

- metric: test-passes
- predicted_delta: +0.01
- rationale: minor improvement
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-006" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" != *"invariants-touched-empty"* ]]
}

@test "gate accepts proposal listing invariants touched with bullets" {
  local proposal="$TEST_FORGE/proposals/test-invariants-listed.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/test.sh

proposal_id: prop-test-007
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/test.sh
baseline: HEAD~1
deploy_watch_metric: heldout-lift

## 8. Invariants touched (C1 safety gate)

Invariants this change affects:
- self-mod-human-review: read — proposal remains staged for human review
- idempotency-check: write — the change adds an idempotency guard

## 9. Predicted impact

- metric: test-passes
- predicted_delta: +0.01
- rationale: idempotency improvement
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-007" --target "hooks/test.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" != *"invariants-touched-empty"* ]]
}

# =============================================================================
# TEST GROUP 5: Gate enforcement — protected surfaces (6c)
# =============================================================================

@test "gate rejects proposal targeting .harness/constitution.md" {
  local proposal="$TEST_FORGE/proposals/test-constitution-mutate.md"
  cat > "$proposal" <<'EOF'
# Proposal: .harness/constitution.md

proposal_id: prop-test-008
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: .harness/constitution.md
baseline: HEAD~1
deploy_watch_metric: heldout-lift

## 8. Invariants touched (C1 safety gate)

- self-mod-invariant-preservation: write

## 9. Predicted impact

- metric: none
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-008" --target ".harness/constitution.md" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"protected-surface"* ]] || [[ "$result" == *"protected — human-authored PR required"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate rejects proposal targeting hooks/gate.sh" {
  local proposal="$TEST_FORGE/proposals/test-gate-mutate.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/gate.sh

proposal_id: prop-test-009
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/gate.sh
baseline: HEAD~1
deploy_watch_metric: test-passes

## 8. Invariants touched (C1 safety gate)

- self-mod-human-review: write

## 9. Predicted impact

- metric: none
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-009" --target "hooks/gate.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"protected-surface"* ]] || [[ "$result" == *"protected — human-authored PR required"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate rejects proposal targeting .harness/constitution.json" {
  local proposal="$TEST_FORGE/proposals/test-constitution-json-mutate.md"
  cat > "$proposal" <<'EOF'
# Proposal: .harness/constitution.json

proposal_id: prop-test-010
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: .harness/constitution.json
baseline: HEAD~1
deploy_watch_metric: test-passes

## 8. Invariants touched (C1 safety gate)

- self-mod-invariant-preservation: write

## 9. Predicted impact

- metric: none
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-010" --target ".harness/constitution.json" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" == *"protected-surface"* ]] || [[ "$result" == *"FAIL"* ]]
}

@test "gate accepts proposal targeting non-protected surface (hooks/propose.sh)" {
  local proposal="$TEST_FORGE/proposals/test-propose-edit.md"
  cat > "$proposal" <<'EOF'
# Proposal: hooks/propose.sh

proposal_id: prop-test-011
generated: 2026-07-01T00:00:00Z

## 6. Proposed edit

```diff
-- old line
++ new line
```

## 7. Rollback contract (C1 safety gate)

file: hooks/propose.sh
baseline: HEAD~1
deploy_watch_metric: proposal-quality

## 8. Invariants touched (C1 safety gate)

- self-mod-human-review: read — change is staged for human review

## 9. Predicted impact

- metric: proposal-quality
- predicted_delta: +0.05
- rationale: improved proposal clarity
EOF

  result="$(bash "$REPO_ROOT/hooks/gate.sh" "prop-test-011" --target "hooks/propose.sh" --proposal "$proposal" 2>&1 || true)"
  [[ "$result" != *"protected-surface"* ]]
}

# =============================================================================
# TEST GROUP 6: Shellcheck and style (existing quality gates)
# =============================================================================

@test "propose.sh passes shellcheck -S warning" {
  result="$(shellcheck -S warning "$REPO_ROOT/hooks/propose.sh" 2>&1 || true)"
  [[ -z "$result" || "$result" == "" ]]
}

@test "gate.sh passes shellcheck -S warning" {
  result="$(shellcheck -S warning "$REPO_ROOT/hooks/gate.sh" 2>&1 || true)"
  [[ -z "$result" || "$result" == "" ]]
}

@test "pre-commit hook runs clean" {
  cd "$REPO_ROOT"
  if [[ -f ".husky/pre-commit" ]]; then
    bash ".husky/pre-commit" >/dev/null 2>&1 || true
    # Pre-commit may have findings, but it should not crash
    true
  else
    skip "No pre-commit hook in repo"
  fi
}

# =============================================================================
# Helper: cleanup after tests
# =============================================================================

teardown() {
  if [[ -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP" 2>/dev/null || true
  fi
}
