#!/usr/bin/env bats
# tests for evals/skills/validate_fixtures.py

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "validate-fixtures: repo fixtures all valid" {
  run python3 "$REPO_ROOT/evals/skills/validate_fixtures.py"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 problems"* ]]
  [[ "$output" == *"5 fixture files"* ]]
}

@test "validate-fixtures: detects bad fixture" {
  bad_dir="$BATS_TEST_TMPDIR/skills/evil/evals"
  mkdir -p "$bad_dir"
  echo '{"skill_name": "other", "evals": [{"prompt": "x"}]}' > "$bad_dir/bad.json"
  run python3 - "$REPO_ROOT" "$bad_dir/bad.json" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/evals/skills")
from validate_fixtures import validate_file
problems = validate_file(sys.argv[2])
assert problems, "expected problems"
assert any("missing 'id'" in p for p in problems), problems
assert any("skill_name" in p for p in problems), problems
EOF
  [ "$status" -eq 0 ]
}
