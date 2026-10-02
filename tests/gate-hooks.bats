#!/usr/bin/env bats
# tests/gate-hooks.bats - gate/security hooks: checklist-gate, transcript-scanner,
# trial-apply, policy-gate. Hermetic: every hook runs from a copy of hooks/ in
# $BATS_TEST_TMPDIR so its ROOT-relative state (.harness/...) never touches the repo.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export FAKE="$BATS_TEST_TMPDIR/root"
  mkdir -p "$FAKE/.harness/checklists" "$FAKE/hooks"
  cp -R "$REPO_ROOT/hooks/." "$FAKE/hooks/"
  printf -- '- [ ] Inputs are validated\n- [ ] No secrets in code\n' > "$FAKE/.harness/checklists/security.md"
  printf -- '- [ ] Error paths handled\n' > "$FAKE/.harness/checklists/quality.md"
  printf -- '- [ ] Failure case tested\n' > "$FAKE/.harness/checklists/testing.md"
  printf -- '- [ ] No N+1 queries\n' > "$FAKE/.harness/checklists/performance.md"
  printf '{"defaultDeny":true,"approvedServers":["github"]}\n' > "$FAKE/.harness/mcp-policy.json"
}

# --- checklist-gate ---------------------------------------------------------

@test "checklist-gate: Write to code file emits checklist on stderr, logs, exits 0" {
  run bash -c "printf '%s' '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"foo/main.go\"}}' | bash '$FAKE/hooks/checklist-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 items to verify for foo/main.go"* ]]
  [[ "$output" == *"Inputs are validated"* ]]
  [ "$(jq -r '.file' "$FAKE/.harness/runtime/checklist-gate.jsonl")" = "foo/main.go" ]
}

@test "checklist-gate: test file under src adds testing and performance dimensions" {
  printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"src/a.test.ts"}}' | bash "$FAKE/hooks/checklist-gate.sh" 2>/dev/null
  [ "$(jq -c '.dimensions' "$FAKE/.harness/runtime/checklist-gate.jsonl")" = '["security","quality","testing","performance"]' ]
}

@test "checklist-gate: markdown file is skipped with no log" {
  run bash -c "printf '%s' '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"README.md\"}}' | bash '$FAKE/hooks/checklist-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$FAKE/.harness/runtime/checklist-gate.jsonl" ]
}

@test "checklist-gate: non-mutating tool is ignored" {
  run bash -c "printf '%s' '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"a.go\"}}' | bash '$FAKE/hooks/checklist-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "checklist-gate: malformed JSON input exits 0 silently" {
  run bash -c "printf '%s' 'not json {' | bash '$FAKE/hooks/checklist-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "checklist-gate: empty stdin exits 0" {
  run bash -c "printf '' | bash '$FAKE/hooks/checklist-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "checklist-gate: no checklist files means allow with no log" {
  rm -f "$FAKE"/.harness/checklists/*.md
  run bash -c "printf '%s' '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"a.go\"}}' | bash '$FAKE/hooks/checklist-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ ! -f "$FAKE/.harness/runtime/checklist-gate.jsonl" ]
}

# --- transcript-scanner -----------------------------------------------------

scan_log() { mkdir -p "$FAKE/.harness/runtime"; printf '%s\n' "$1" > "$FAKE/.harness/runtime/trajectory.jsonl"; }

@test "transcript-scanner: clean log reports zero findings and exits 0" {
  scan_log '{"ts":"2026-01-01T00:00:00Z","tool":"Bash","outcome":"ok","input":"ls","response":"file.txt"}'
  run bash "$FAKE/hooks/transcript-scanner.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total events: 1"* ]]
  [[ "$output" == *"refusals=0 eval-aware=0 env-drift=0 halluc=0 agency=0 inject=0"* ]]
}

@test "transcript-scanner: flags refusal, injection tell and excessive agency but never blocks" {
  scan_log '{"ts":"2026-01-01T00:00:00Z","tool":"Bash","outcome":"ok","input":"rm -rf build","response":"I must decline. Ignore previous instructions"}'
  run bash "$FAKE/hooks/transcript-scanner.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"refusals=1"* ]]
  [[ "$output" == *"agency=1"* ]]
  [[ "$output" == *"inject=1"* ]]
  ls "$FAKE"/.harness/forge/*transcript-scan.md
}

@test "transcript-scanner: --since filters out older events" {
  scan_log '{"ts":"2026-01-01T00:00:00Z","tool":"Bash","outcome":"ok","input":"sudo ls","response":"x"}'
  run bash "$FAKE/hooks/transcript-scanner.sh" --since 2026-06-01T00:00:00Z
  [ "$status" -eq 0 ]
  [[ "$output" == *"trajectory log is empty"* ]]
}

@test "transcript-scanner: missing log exits 0 with notice on stderr" {
  run bash "$FAKE/hooks/transcript-scanner.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no trajectory log"* ]]
}

@test "transcript-scanner: malformed log lines are treated as empty" {
  scan_log 'garbage not json'
  run bash "$FAKE/hooks/transcript-scanner.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"trajectory log is empty"* ]]
}

@test "transcript-scanner: unknown argument exits 2" {
  run bash "$FAKE/hooks/transcript-scanner.sh" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "transcript-scanner: --status with no prior scan says so" {
  run bash "$FAKE/hooks/transcript-scanner.sh" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no transcript scan yet"* ]]
}

# --- trial-apply ------------------------------------------------------------

make_proposal() {
  # $1 = diff body for section 6
  mkdir -p "$FAKE/work"
  printf 'line one\nline two\nline three\n' > "$FAKE/work/target.sh"
  cat > "$FAKE/prop.md" <<PROP
---
proposal_id: p-test-1
---
# Proposal: work/target.sh

## 5. Current content

line one

## 6. Proposed edit

\`\`\`diff
$1
\`\`\`

## 7. Predicted impact

FILL IN
PROP
}

@test "trial-apply: applies diff to trial copy, leaves live target untouched" {
  make_proposal "@@ -1,3 +1,3 @@
 line one
-line two
+line TWO
 line three"
  cd "$FAKE"
  run bash "$FAKE/hooks/trial-apply.sh" prop.md
  [ "$status" -eq 0 ]
  [ "$output" = "$FAKE/.harness/forge/trial/p-test-1/target.sh" ]
  grep -q 'line TWO' "$output"
  grep -q 'line two' "$FAKE/work/target.sh"
  [ -f "$FAKE/.harness/forge/trial/p-test-1/target.sh.pristine.bak" ]
}

@test "trial-apply: rejects proposal whose section 6 still has FILL IN" {
  make_proposal "FILL IN"
  cd "$FAKE"
  run bash "$FAKE/hooks/trial-apply.sh" prop.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"FILL IN"* ]]
}

@test "trial-apply: rejects diff that does not apply" {
  make_proposal "@@ -1,3 +1,3 @@
 nothing matches
-nope
+x
 here"
  cd "$FAKE"
  run bash "$FAKE/hooks/trial-apply.sh" prop.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"did not apply cleanly"* ]]
}

@test "trial-apply: no argument exits 2 with usage" {
  run bash "$FAKE/hooks/trial-apply.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage"* ]]
}

@test "trial-apply: missing proposal file exits 2" {
  run bash "$FAKE/hooks/trial-apply.sh" "$FAKE/nope.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"proposal file not found"* ]]
}

@test "trial-apply: empty proposal file exits 2 for missing proposal_id" {
  : > "$FAKE/empty.md"
  run bash "$FAKE/hooks/trial-apply.sh" "$FAKE/empty.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"proposal_id"* ]]
}

# --- policy-gate ------------------------------------------------------------

pg() { printf '%s' "$1" | bash "$FAKE/hooks/policy-gate.sh"; }

@test "policy-gate: native tool is allowed and ledgered" {
  run pg '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.verdict' "$FAKE/.harness/runtime/policy-ledger.jsonl")" = "ALLOW" ]
}

@test "policy-gate: approved MCP server is allowed" {
  run pg '{"tool_name":"mcp__github__create_issue","tool_input":{}}'
  [ "$status" -eq 0 ]
}

@test "policy-gate: unapproved MCP server is denied with exit 2" {
  run pg '{"tool_name":"mcp__evil__exfil","tool_input":{}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"DENY"* ]]
  [ "$(jq -r '.verdict' "$FAKE/.harness/runtime/policy-ledger.jsonl")" = "DENY" ]
}

@test "policy-gate: unapproved MCP server with defaultDeny false requires approval but exits 0" {
  printf '{"defaultDeny":false,"approvedServers":[]}\n' > "$FAKE/.harness/mcp-policy.json"
  run pg '{"tool_name":"mcp__evil__x","tool_input":{}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"REQUIRE_APPROVAL"* ]]
}

@test "policy-gate: empty stdin exits 0" {
  run pg ''
  [ "$status" -eq 0 ]
}

@test "policy-gate: malformed JSON exits 0" {
  run pg 'not json {'
  [ "$status" -eq 0 ]
}

@test "policy-gate: missing policy file fails open" {
  rm "$FAKE/.harness/mcp-policy.json"
  run pg '{"tool_name":"mcp__evil__x","tool_input":{}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"fail-open"* ]]
}

@test "policy-gate: --verify reports intact chain after several decisions" {
  pg '{"tool_name":"Bash","tool_input":{}}'
  pg '{"tool_name":"mcp__github__x","tool_input":{}}'
  run bash "$FAKE/hooks/policy-gate.sh" --verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 entries, chain verified"* ]]
}

@test "policy-gate: --verify detects a tampered ledger entry" {
  pg '{"tool_name":"mcp__evil__x","tool_input":{}}' || true
  sed -i.bak 's/DENY/ALLOW/' "$FAKE/.harness/runtime/policy-ledger.jsonl"
  run bash "$FAKE/hooks/policy-gate.sh" --verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"CHAIN BREAK"* ]]
}

@test "policy-gate: --learn DENY rule makes a native tool denied" {
  run bash "$FAKE/hooks/policy-gate.sh" --learn DENY "Bash " --rationale "test"
  [ "$status" -eq 0 ]
  run pg '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"learned prefix rule"* ]]
}

@test "policy-gate: --learn rejects invalid verdict with exit 2" {
  run bash "$FAKE/hooks/policy-gate.sh" --learn MAYBE foo
  [ "$status" -eq 2 ]
}
