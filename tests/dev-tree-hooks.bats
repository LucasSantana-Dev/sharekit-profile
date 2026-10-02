#!/usr/bin/env bats
# tests/dev-tree-hooks.bats - repo-root hooks: check-harness-drift, check-idempotency,
# model-cache-guard, observe-otel, post-incident-adr, repo-map.
# Hermetic: hooks run from a copy of hooks/ in $BATS_TEST_TMPDIR (ROOT-relative state
# lands in the copy) and HOME points inside the tmpdir. No network.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export FAKE="$BATS_TEST_TMPDIR/root"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE/hooks" "$FAKE/.harness/runtime" "$HOME"
  cp -R "$REPO_ROOT/hooks/." "$FAKE/hooks/"
  RT="$FAKE/.harness/runtime"
  unset OBSERVE_LEVEL OBSERVE_DEST OBSERVE_HOOK_EVENT OBSERVE_CTX_LIMIT OTEL_EXPORTER_OTLP_ENDPOINT
}

hook() { local h="$1"; shift; bash "$FAKE/hooks/$h.sh" "$@"; }
feed() { local h="$1" in="$2"; shift 2; printf '%s' "$in" | bash "$FAKE/hooks/$h.sh" "$@"; }
need() { command -v "$1" >/dev/null 2>&1 || skip "$1 not installed"; }

# --- check-harness-drift ----------------------------------------------------

@test "check-harness-drift: skips with a warning and exit 0 when ~/.claude-env is missing" {
  run hook check-harness-drift
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "check-harness-drift: identical agents and hooks trees report ok" {
  for t in .claude .claude-env; do
    mkdir -p "$HOME/$t/agents" "$HOME/$t/hooks"
    echo a > "$HOME/$t/agents/x.md"; echo h > "$HOME/$t/hooks/y.sh"
  done
  run hook check-harness-drift
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok: no harness drift"* ]]
}

@test "check-harness-drift: changed file content exits 1 and names the subtree" {
  for t in .claude .claude-env; do mkdir -p "$HOME/$t/hooks"; done
  echo one > "$HOME/.claude/hooks/y.sh"; echo two > "$HOME/.claude-env/hooks/y.sh"
  run hook check-harness-drift
  [ "$status" -eq 1 ]
  [[ "$output" == *"drift detected in hooks/"* ]]
}

@test "check-harness-drift: subtree present on only one side is drift" {
  mkdir -p "$HOME/.claude-env/agents" "$HOME/.claude"
  run hook check-harness-drift
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing (only present in"* ]]
}

@test "check-harness-drift: rtk-rewrite.sh and .rtk-hook.sha256 are allowlisted" {
  for t in .claude .claude-env; do mkdir -p "$HOME/$t/hooks"; done
  echo x > "$HOME/.claude/hooks/rtk-rewrite.sh"; echo y > "$HOME/.claude/hooks/.rtk-hook.sha256"
  run hook check-harness-drift
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok: no harness drift"* ]]
}

# --- check-idempotency ------------------------------------------------------

@test "check-idempotency: unverified git push is logged and hinted, exit 0" {
  need jq; need rg
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin x\"}}' | bash '$FAKE/hooks/check-idempotency.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"HINT: state-check before mutation"* ]]
  [ "$(jq -r '.event' "$RT/idempotency.jsonl")" = "unverified-mutation" ]
  [ "$(jq -r '.command' "$RT/idempotency.jsonl")" = "git push origin x" ]
}

@test "check-idempotency: Write tool is logged without needing a command" {
  need jq
  run feed check-idempotency '{"tool_name":"Write","tool_input":{"file_path":"/x"}}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tool' "$RT/idempotency.jsonl")" = "Write" ]
}

@test "check-idempotency: read-only Bash command is not logged" {
  need jq; need rg
  run feed check-idempotency '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
  [ ! -s "$RT/idempotency.jsonl" ]
}

@test "check-idempotency: non-mutating tool is ignored" {
  need jq
  run feed check-idempotency '{"tool_name":"Read","tool_input":{"file_path":"/x"}}'
  [ "$status" -eq 0 ]
  [ ! -s "$RT/idempotency.jsonl" ]
}

@test "check-idempotency: malformed stdin exits 0 without logging" {
  need jq
  run feed check-idempotency 'not json {'
  [ "$status" -eq 0 ]
  [ ! -s "$RT/idempotency.jsonl" ]
}

@test "check-idempotency: empty stdin exits 0 without logging" {
  need jq
  run feed check-idempotency ''
  [ "$status" -eq 0 ]
  [ ! -s "$RT/idempotency.jsonl" ]
}

# --- model-cache-guard ------------------------------------------------------

@test "model-cache-guard: first turn records a user-turn and stays quiet" {
  need jq
  run bash -c "printf '%s' '{\"model\":\"opus\"}' | bash '$FAKE/hooks/model-cache-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r '.turn' "$RT/model-session.jsonl")" = "1" ]
  [ ! -e "$RT/model-switches.jsonl" ]
}

@test "model-cache-guard: mid-conversation model change warns cache-UNSAFE and logs safe=false" {
  need jq
  feed model-cache-guard '{"model":"opus"}'
  feed model-cache-guard '{"model":"opus"}'
  run bash -c "printf '%s' '{\"model\":\"sonnet\"}' | bash '$FAKE/hooks/model-cache-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cache-UNSAFE model switch at turn 3"* ]]
  [ "$(jq -r '.safe' "$RT/model-switches.jsonl")" = "false" ]
  [ "$(jq -r '.reason' "$RT/model-switches.jsonl")" = "mid-conversation" ]
}

@test "model-cache-guard: switch right after PostCompact is cache-safe" {
  need jq
  feed model-cache-guard '{"model":"opus"}'
  printf '%s' '{"model":"opus"}' | OBSERVE_HOOK_EVENT=PostCompact bash "$FAKE/hooks/model-cache-guard.sh"
  run bash -c "printf '%s' '{\"model\":\"sonnet\"}' | bash '$FAKE/hooks/model-cache-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cache-safe model switch"* ]]
  [ "$(jq -r '.reason' "$RT/model-switches.jsonl")" = "post-compaction" ]
}

@test "model-cache-guard: payload without a model signature exits 0 and records nothing" {
  run feed model-cache-guard '{"foo":1}'
  [ "$status" -eq 0 ]
  [ ! -e "$RT/model-session.jsonl" ]
}

@test "model-cache-guard: empty and malformed stdin exit 0" {
  run feed model-cache-guard ''
  [ "$status" -eq 0 ]
  run feed model-cache-guard 'garbage {'
  [ "$status" -eq 0 ]
  [ ! -e "$RT/model-session.jsonl" ]
}

@test "model-cache-guard: --status with no events says so" {
  run hook model-cache-guard --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no model-switch events recorded"* ]]
}

@test "model-cache-guard: --status counts unsafe switches" {
  need jq; need rg
  feed model-cache-guard '{"model":"a"}'
  feed model-cache-guard '{"model":"a"}'
  feed model-cache-guard '{"model":"b"}' 2>/dev/null
  run hook model-cache-guard --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"model-switch events: 1"* ]]
  [[ "$output" == *"cache-unsafe (mid-conversation): 1"* ]]
  [[ "$output" == *"recent cache-unsafe switches:"* ]]
}

@test "model-cache-guard: --reset truncates the session tracker" {
  need jq
  feed model-cache-guard '{"model":"a"}'
  [ -s "$RT/model-session.jsonl" ]
  run hook model-cache-guard --reset
  [ "$status" -eq 0 ]
  [ ! -s "$RT/model-session.jsonl" ]
}

# --- observe-otel -----------------------------------------------------------

@test "observe-otel: PostToolUse writes a gen_ai.tool.call span to jsonl by default" {
  need jq
  run feed observe-otel '{"tool_name":"Bash","session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.name' "$RT/otel-spans.jsonl")" = "gen_ai.tool.call" ]
  [ "$(jq -r '.tool' "$RT/otel-spans.jsonl")" = "Bash" ]
  [ "$(jq -r '.session' "$RT/otel-spans.jsonl")" = "s1" ]
}

@test "observe-otel: OBSERVE_HOOK_EVENT=SessionStart emits a session.start span" {
  need jq
  printf '%s' '{"session_id":"s2"}' | OBSERVE_HOOK_EVENT=SessionStart bash "$FAKE/hooks/observe-otel.sh"
  [ "$(jq -r '.name' "$RT/otel-spans.jsonl")" = "gen_ai.session.start" ]
}

@test "observe-otel: OBSERVE_HOOK_EVENT=SessionEnd emits a session.end span" {
  need jq
  printf '%s' '{"session_id":"s2"}' | OBSERVE_HOOK_EVENT=SessionEnd bash "$FAKE/hooks/observe-otel.sh"
  [ "$(jq -r '.name' "$RT/otel-spans.jsonl")" = "gen_ai.session.end" ]
}

@test "observe-otel: OBSERVE_LEVEL=off emits nothing" {
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\"}' | OBSERVE_LEVEL=off bash '$FAKE/hooks/observe-otel.sh'"
  [ "$status" -eq 0 ]
  [ ! -e "$RT/otel-spans.jsonl" ]
}

@test "observe-otel: level off in .harness/observe.json is honoured when env is unset" {
  echo '{"level":"off"}' > "$FAKE/.harness/observe.json"
  run feed observe-otel '{"tool_name":"Bash"}'
  [ "$status" -eq 0 ]
  [ ! -e "$RT/otel-spans.jsonl" ]
}

@test "observe-otel: OBSERVE_DEST=stderr sends the span to stderr, not the file" {
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\"}' | OBSERVE_DEST=stderr bash '$FAKE/hooks/observe-otel.sh' 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gen_ai.tool.call"* ]]
  [ ! -e "$RT/otel-spans.jsonl" ]
}

@test "observe-otel: OBSERVE_DEST=otel without endpoint falls back to the local jsonl (no network)" {
  printf '%s' '{"tool_name":"Bash"}' | OBSERVE_DEST=otel bash "$FAKE/hooks/observe-otel.sh"
  [ -s "$RT/otel-spans.jsonl" ]
}

@test "observe-otel: context breach span and nudge fire when trajectory exceeds OBSERVE_CTX_LIMIT" {
  need jq
  printf '%s\n' '{"response":"aaaaaaaaaaaaaaaaaaaa","input":"bbbbbbbbbb"}' > "$RT/trajectory.jsonl"
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"session_id\":\"s3\"}' | OBSERVE_CTX_LIMIT=10 bash '$FAKE/hooks/observe-otel.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"context breach"* ]]
  grep -q '"name":"context.breach"' "$RT/otel-spans.jsonl"
}

@test "observe-otel: no breach when trajectory is under the limit" {
  need jq
  printf '%s\n' '{"response":"a","input":"b"}' > "$RT/trajectory.jsonl"
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\"}' | bash '$FAKE/hooks/observe-otel.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"context breach"* ]]
}

@test "observe-otel: empty stdin exits 0 and still writes a span" {
  run feed observe-otel ''
  [ "$status" -eq 0 ]
  [ -s "$RT/otel-spans.jsonl" ]
}

@test "observe-otel: malformed stdin exits 0" {
  run feed observe-otel 'not json {'
  [ "$status" -eq 0 ]
}

@test "observe-otel: feedback +1 records a score" {
  run hook observe-otel feedback +1 "good run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feedback recorded: +1"* ]]
  grep -q '"score":+1' "$RT/feedback.jsonl"
}

@test "observe-otel: feedback with an invalid score exits 2 and records nothing" {
  run hook observe-otel feedback 5 "bad"
  [ "$status" -eq 2 ]
  [ ! -e "$RT/feedback.jsonl" ]
}

@test "observe-otel: status prints knobs honouring env overrides" {
  run bash -c "OBSERVE_LEVEL=trace OBSERVE_DEST=stderr bash '$FAKE/hooks/observe-otel.sh' status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"level=trace dest=stderr"* ]]
}

# --- post-incident-adr ------------------------------------------------------

@test "post-incident-adr: no trajectory log exits 0 silently" {
  run hook post-incident-adr
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$RT/incidents.jsonl" ]
}

@test "post-incident-adr: three error/blocked outcomes record a P1 stub and remind" {
  need jq
  printf '%s\n' '{"ts":"1","outcome":"error"}' '{"ts":"2","outcome":"blocked"}' '{"ts":"3","outcome":"error"}' '{"ts":"4","outcome":"ok"}' > "$RT/trajectory.jsonl"
  run bash -c "bash '$FAKE/hooks/post-incident-adr.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 error/blocked tool outcomes"* ]]
  [ "$(jq -r '.severity' "$RT/incidents.jsonl")" = "P1-candidate" ]
  [ "$(jq -r '.error_count' "$RT/incidents.jsonl")" = "3" ]
}

@test "post-incident-adr: two errors stay under the threshold" {
  need jq
  printf '%s\n' '{"ts":"1","outcome":"error"}' '{"ts":"2","outcome":"error"}' > "$RT/trajectory.jsonl"
  run hook post-incident-adr
  [ "$status" -eq 0 ]
  [ ! -s "$RT/incidents.jsonl" ]
}

@test "post-incident-adr: empty trajectory exits 0 without an incident" {
  : > "$RT/trajectory.jsonl"
  run hook post-incident-adr
  [ "$status" -eq 0 ]
  [ ! -s "$RT/incidents.jsonl" ]
}

@test "post-incident-adr: malformed trajectory exits 0 without an incident" {
  printf 'not json\n{{{\n' > "$RT/trajectory.jsonl"
  run hook post-incident-adr
  [ "$status" -eq 0 ]
  [ ! -s "$RT/incidents.jsonl" ]
}

# --- repo-map ---------------------------------------------------------------

@test "repo-map: writes md and json maps listing files and symbols" {
  need fd; need rg; need jq
  rm -rf "$FAKE/hooks"; mkdir -p "$FAKE/hooks" "$FAKE/src"
  cp "$REPO_ROOT/hooks/repo-map.sh" "$FAKE/hooks/"
  printf 'function alpha_fn() { :; }\n' > "$FAKE/src/a.sh"
  run hook repo-map
  [ "$status" -eq 0 ]
  [[ "$output" == *"repo-map written:"* ]]
  grep -q 'src/a.sh' "$RT/repo-map.md"
  grep -q 'alpha_fn' "$RT/repo-map.md"
  jq -e '.file_count >= 1' "$RT/repo-map.json" >/dev/null
}

@test "repo-map: node_modules and .git are excluded from the map" {
  need fd; need rg
  rm -rf "$FAKE/hooks"; mkdir -p "$FAKE/hooks" "$FAKE/node_modules/pkg" "$FAKE/.git"
  cp "$REPO_ROOT/hooks/repo-map.sh" "$FAKE/hooks/"
  echo x > "$FAKE/node_modules/pkg/leak.js"; echo x > "$FAKE/.git/leak2"
  run hook repo-map
  [ "$status" -eq 0 ]
  ! grep -q 'leak' "$RT/repo-map.md"
}

@test "repo-map: symbol index is capped by the byte budget" {
  need fd; need rg
  rm -rf "$FAKE/hooks"; mkdir -p "$FAKE/hooks" "$FAKE/src"
  cp "$REPO_ROOT/hooks/repo-map.sh" "$FAKE/hooks/"
  for i in $(seq 1 600); do echo "function fn_number_$i() { :; }"; done > "$FAKE/src/big.sh"
  run hook repo-map
  [ "$status" -eq 0 ]
  ! grep -q 'fn_number_600' "$RT/repo-map.md"
}

@test "repo-map: --status without a map says to generate one" {
  rm -f "$RT/repo-map.md"
  run hook repo-map --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no repo map yet"* ]]
}

@test "repo-map: --status reports sizes after generation" {
  need fd; need rg
  hook repo-map >/dev/null
  run hook repo-map --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=8192"* ]]
}

@test "repo-map: empty repo (no files besides the script) still exits 0" {
  need fd; need rg
  rm -rf "$FAKE/hooks"; mkdir -p "$FAKE/hooks"
  cp "$REPO_ROOT/hooks/repo-map.sh" "$FAKE/hooks/"
  run hook repo-map
  [ "$status" -eq 0 ]
  [ -s "$RT/repo-map.json" ]
}
