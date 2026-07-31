#!/usr/bin/env bats
# tests for the review-pack output contract:
#   claude/agents/review/coordinator-schema.json + scripts/review-fingerprint.sh

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/review-pack-$$"
  mkdir -p "$TEST_TMP"
  export SCHEMA="$REPO_ROOT/claude/agents/review/coordinator-schema.json"
  export FINGERPRINT="$REPO_ROOT/scripts/review-fingerprint.sh"
}

mkfixture() {
  # $1 = output file; a schema-valid coordinator payload with one finding
  cat > "$1" <<'JSON'
{
  "event": "REQUEST_CHANGES",
  "summary": "One critical finding: user input reaches a shell command unsanitized.",
  "findings": [
    {
      "path": "src/main.ts",
      "position": 12,
      "severity": "critical",
      "rule_id": "security/command-injection",
      "body": "Unsanitized input is passed to exec(); validate or parameterize it.",
      "fingerprint": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
  ]
}
JSON
}

@test "coordinator schema parses as JSON (jq empty)" {
  run jq empty "$SCHEMA"
  [ "$status" -eq 0 ]
}

@test "coordinator schema enforces contract shape" {
  run jq -e '
    .additionalProperties == false and
    (.required | sort == ["event", "findings", "summary"]) and
    (.properties.event.enum | sort == ["APPROVE", "COMMENT", "REQUEST_CHANGES"]) and
    (.properties.findings.items.additionalProperties == false) and
    (.properties.findings.items.required | sort == ["body", "fingerprint", "path", "position", "rule_id", "severity"]) and
    (.properties.findings.items.properties.severity.enum | sort == ["critical", "suggestion", "warning"]) and
    (.properties.findings.items.properties.position.type == "integer") and
    (.properties.findings.items.properties.fingerprint.pattern == "^[0-9a-f]{64}$")
  ' "$SCHEMA" >/dev/null
  [ "$status" -eq 0 ]
}

@test "valid fixture payload validates against the schema" {
  mkfixture "$TEST_TMP/valid.json"
  if python3 -c 'import jsonschema' 2>/dev/null; then
    run python3 - "$SCHEMA" "$TEST_TMP/valid.json" <<'PY'
import json, sys
import jsonschema
schema = json.load(open(sys.argv[1]))
payload = json.load(open(sys.argv[2]))
jsonschema.validate(payload, schema)
PY
    [ "$status" -eq 0 ]
  else
    # structural jq fallback when python3-jsonschema is unavailable
    run jq -e '
      (keys | sort == ["event", "findings", "summary"]) and
      (.event | IN("APPROVE"; "COMMENT"; "REQUEST_CHANGES")) and
      (.summary | type == "string") and
      (.findings | type == "array") and
      (.findings | all(
        (keys | sort == ["body", "fingerprint", "path", "position", "rule_id", "severity"]) and
        (.path | type == "string") and
        (.position | type == "number" and (. == floor)) and
        (.severity | IN("critical"; "suggestion"; "warning")) and
        (.rule_id | type == "string") and
        (.body | type == "string") and
        (.fingerprint | test("^[0-9a-f]{64}$"))
      ))
    ' "$TEST_TMP/valid.json" >/dev/null
    [ "$status" -eq 0 ]
  fi
}

@test "fingerprint is a 64-char lowercase hex sha256" {
  run bash "$FINGERPRINT" "src/main.ts" "security/command-injection" "exec(userInput)"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "fingerprint is stable when the same snippet moves from line 10 to line 42" {
  {
    for i in $(seq 1 9); do echo "filler line $i"; done
    echo 'const q = `SELECT * FROM users WHERE id = ${id}`;'
    for i in $(seq 11 41); do echo "filler line $i"; done
    echo 'const q = `SELECT * FROM users WHERE id = ${id}`;'
  } > "$TEST_TMP/moved.txt"

  fp10="$(sed -n '10p' "$TEST_TMP/moved.txt" | bash "$FINGERPRINT" "db/users.ts" "sql/string-interpolation")"
  fp42="$(sed -n '42p' "$TEST_TMP/moved.txt" | bash "$FINGERPRINT" "db/users.ts" "sql/string-interpolation")"
  [ "$fp10" = "$fp42" ]
}

@test "fingerprint ignores whitespace-only and collapsed-whitespace differences" {
  printf 'if (x) {\n  run(x);\n}\n' > "$TEST_TMP/a.txt"
  printf 'if (x) {   run(x); }\n\n\n' > "$TEST_TMP/b.txt"
  fpa="$(bash "$FINGERPRINT" "a.ts" "style/noop" < "$TEST_TMP/a.txt")"
  fpb="$(bash "$FINGERPRINT" "a.ts" "style/noop" < "$TEST_TMP/b.txt")"
  [ "$fpa" = "$fpb" ]
}

@test "fingerprint differs when snippet content changes" {
  fp_a="$(bash "$FINGERPRINT" "src/main.ts" "security/command-injection" "exec(userInput)")"
  fp_b="$(bash "$FINGERPRINT" "src/main.ts" "security/command-injection" "exec(sanitizedInput)")"
  [ "$fp_a" != "$fp_b" ]
}

@test "fingerprint differs when path or rule_id changes" {
  fp_a="$(bash "$FINGERPRINT" "src/main.ts" "security/command-injection" "exec(userInput)")"
  fp_path="$(bash "$FINGERPRINT" "src/other.ts" "security/command-injection" "exec(userInput)")"
  fp_rule="$(bash "$FINGERPRINT" "src/main.ts" "security/other-rule" "exec(userInput)")"
  [ "$fp_a" != "$fp_path" ]
  [ "$fp_a" != "$fp_rule" ]
}
