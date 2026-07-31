#!/usr/bin/env bats
# tests/evals.bats - offline tests for evals/routing/ (skill-routing eval gate)
# Hermetic: the mock model fixture stands in for OpenRouter, no network needed.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export EVAL="$REPO_ROOT/evals/routing/router_eval.py"
  export MOCK="$REPO_ROOT/tests/fixtures/mock_router_model.py"
  export MOCK_PORT=18099
  export OPENROUTER_API_KEY="test-key-not-real"
}

teardown() {
  [ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null || true
}

start_mock() {
  MOCK_PORT=$MOCK_PORT MOCK_MODE="$1" python3 "$MOCK" &
  MOCK_PID=$!
  for _ in $(seq 1 50); do
    curl -sf -o /dev/null "http://127.0.0.1:$MOCK_PORT/" && break || sleep 0.1
  done
  export OPENROUTER_BASE_URL="http://127.0.0.1:$MOCK_PORT"
}

@test "router_eval: --validate-only passes on shipped datasets and baseline" {
  python3 "$EVAL" --validate-only
  [ $? -eq 0 ]
}

@test "router_eval: --validate-only reports skills and tasks counts" {
  result=$(python3 "$EVAL" --validate-only 2>&1)
  [[ "$result" == *"0 problems"* ]]
  [[ "$result" == *"40 tasks"* ]]
}

@test "router_eval: missing API key exits 2" {
  run env -u OPENROUTER_API_KEY python3 "$EVAL"
  [ "$status" -eq 2 ]
}

@test "router_eval: gate PASSes when model answers expected skills (oracle mock)" {
  start_mock oracle
  run python3 "$EVAL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GATE PASS"* ]]
  [[ "$output" == *"= 1.000"* ]]
  [[ "$output" == *"skipped: expected skill not in listing"* ]]
}

@test "router_eval: gate FAILs when model regresses (always-none mock)" {
  start_mock always_none
  run python3 "$EVAL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GATE FAIL"* ]]
  [[ "$output" == *"regressions:"* ]]
}

@test "router_eval: --set-baseline writes a baseline file" {
  start_mock oracle
  export TMP_EVAL_DIR="$BATS_TEST_TMPDIR/evals-$$"
  cp -r "$REPO_ROOT/evals/routing" "$TMP_EVAL_DIR"
  rm -f "$TMP_EVAL_DIR/baseline/routing_baseline.json"
  python3 "$TMP_EVAL_DIR/router_eval.py" --set-baseline >/dev/null
  [ -f "$TMP_EVAL_DIR/baseline/routing_baseline.json" ]
  acc=$(python3 -c "import json; print(json.load(open('$TMP_EVAL_DIR/baseline/routing_baseline.json'))['accuracy'])")
  [ "$acc" = "1.0" ]
}

@test "router_eval: missing baseline exits 2 with guidance" {
  export TMP_EVAL_DIR2="$BATS_TEST_TMPDIR/evals-nobase-$$"
  cp -r "$REPO_ROOT/evals/routing" "$TMP_EVAL_DIR2"
  rm -f "$TMP_EVAL_DIR2/baseline/routing_baseline.json"
  start_mock oracle
  run python3 "$TMP_EVAL_DIR2/router_eval.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no baseline found"* ]]
}

@test "datasets: every task has id, prompt, expected and unique id" {
  python3 - "$REPO_ROOT" <<'EOF'
import glob, json, sys
ids = set()
n = 0
for path in sorted(glob.glob(sys.argv[1] + "/evals/routing/dataset/routing_*.jsonl")):
    for line in open(path):
        d = json.loads(line)
        assert all(k in d for k in ("id", "prompt", "expected")), d
        assert d["id"] not in ids, f"dup id {d['id']}"
        ids.add(d["id"])
        n += 1
assert n == 40, f"expected 40 tasks, got {n}"
EOF
}

@test "datasets: no personal paths or home-dir leaks in shipped tasks" {
  ! grep -qE '/Users/|External HD|lucassantana' "$REPO_ROOT"/evals/routing/dataset/routing_*.jsonl
}
