#!/usr/bin/env bats
# tests for hooks/check-llm-policy.sh (soft LLM tier policy enforcement)

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/llm-policy-$$"
  mkdir -p "$TEST_TMP"
  export LLM_POLICY_FILE="$TEST_TMP/llm-policy.json"
}

mkpolicy() {
  cat > "$LLM_POLICY_FILE" <<'JSON'
{
  "policy_version": "1.0",
  "defaultDeny": true,
  "enforcement": "fail-open",
  "tiers": {
    "haiku": {"models": ["anthropic/claude-haiku-4-5"]},
    "sonnet": {"models": ["anthropic/claude-sonnet-4-5"]},
    "opus": {"models": ["anthropic/claude-opus-4-8"]}
  },
  "roleTiers": {
    "default": "sonnet",
    "mechanical": "haiku",
    "deep-reasoning": "opus"
  }
}
JSON
}

@test "check-llm-policy: missing policy file fails open" {
  rm -f "$LLM_POLICY_FILE"
  run bash -c 'echo "{\"model\": \"anthropic/claude-opus-4-8\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fail-open"* ]]
}

@test "check-llm-policy: at-tier request passes silently" {
  mkpolicy
  run bash -c 'echo "{\"model\": \"anthropic/claude-sonnet-4-5\", \"agent_role\": \"implementation\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

@test "check-llm-policy: above-tier request warns but exits 0 (fail-open)" {
  mkpolicy
  run bash -c 'echo "{\"model\": \"anthropic/claude-opus-4-8\", \"agent_role\": \"mechanical\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"mechanical"* ]]
  [[ "$output" == *"gateway"* ]]
}

@test "check-llm-policy: unknown role resolves to default tier" {
  mkpolicy
  run bash -c 'echo "{\"model\": \"anthropic/claude-opus-4-8\", \"agent_role\": \"no-such-role\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"sonnet"* ]]
}

@test "check-llm-policy: unlisted model warns under defaultDeny" {
  mkpolicy
  run bash -c 'echo "{\"model\": \"vendor/mystery-9\", \"agent_role\": \"deep-reasoning\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"defaultDeny"* ]]
}

@test "check-llm-policy: model tier resolved by name substring" {
  mkpolicy
  run bash -c 'echo "{\"model\": \"anthropic/claude-opus-9-x\", \"agent_role\": \"mechanical\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier 'opus'"* ]]
}

@test "check-llm-policy: fail-closed enforcement blocks with exit 2" {
  mkpolicy
  jq '.enforcement = "fail-closed"' "$LLM_POLICY_FILE" > "$TEST_TMP/tmp.json" \
    && mv "$TEST_TMP/tmp.json" "$LLM_POLICY_FILE"
  run bash -c 'echo "{\"model\": \"anthropic/claude-opus-4-8\", \"agent_role\": \"mechanical\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"blocking"* ]]
}

@test "check-llm-policy: no model in input passes through" {
  mkpolicy
  run bash -c 'echo "{\"tool_name\": \"Bash\"}" | bash "$1"' _ \
    "$REPO_ROOT/hooks/check-llm-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

@test "check-llm-policy: repo policy file is valid JSON with required keys" {
  run jq -e '.defaultDeny == true and .enforcement and .tiers and .roleTiers and .budgets and .fallbackChain and .attributionTags' \
    "$REPO_ROOT/.harness/llm-policy.json"
  [ "$status" -eq 0 ]
}
