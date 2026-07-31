#!/usr/bin/env bats
# tests/marketplace.bats - Drift-guard tests for .claude-plugin/marketplace.json
# Pattern mirrors scripts/check-catalog.sh: the marketplace manifest must stay
# in sync with the curated-*.txt lists and the paths it references.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/marketplace-$$"
  mkdir -p "$TEST_TMP"
}

# Build a minimal fake repo root that the script can validate.
mk_fixture() { # $1 = fixture root
  mkdir -p "$1/.claude-plugin" "$1/claude/skills/demo-skill" "$1/claude/hooks"
  touch "$1/claude/hooks/demo-hook.sh"
  printf 'demo-skill\n' > "$1/curated-skills.txt"
  printf 'demo-hook.sh\n' > "$1/curated-hooks.txt"
  cat > "$1/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "fixture",
  "owner": { "name": "Test" },
  "plugins": [
    {
      "name": "core-skills",
      "source": "./claude/skills",
      "description": "Fixture skills plugin",
      "version": "1.0.0"
    },
    {
      "name": "security-hooks",
      "source": "./claude/hooks",
      "description": "Fixture hooks plugin",
      "version": "1.0.0"
    }
  ]
}
EOF
}

@test "marketplace.json exists and parses" {
  [ -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]
  python3 -m json.tool "$REPO_ROOT/.claude-plugin/marketplace.json" >/dev/null
}

@test "check-marketplace: repo marketplace passes" {
  result=$( bash "$REPO_ROOT/scripts/check-marketplace.sh" 2>&1 )
  [ $? -eq 0 ]
  [[ "$result" == *"marketplace checks passed"* ]]
}

@test "check-marketplace: valid fixture passes" {
  mk_fixture "$TEST_TMP/ok"
  bash "$REPO_ROOT/scripts/check-marketplace.sh" "$TEST_TMP/ok"
  [ $? -eq 0 ]
}

@test "check-marketplace: curated entry missing from source dir fails" {
  mk_fixture "$TEST_TMP/drift"
  printf 'ghost-skill\n' >> "$TEST_TMP/drift/curated-skills.txt"
  result=$( bash "$REPO_ROOT/scripts/check-marketplace.sh" "$TEST_TMP/drift" 2>&1 || true )
  [[ "$result" == *"FAIL"* ]]
  [[ "$result" == *"ghost-skill"* ]]
}

@test "check-marketplace: curated list with no covering plugin fails" {
  mk_fixture "$TEST_TMP/noplugin"
  python3 - "$TEST_TMP/noplugin/.claude-plugin/marketplace.json" <<'EOF'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
data["plugins"] = [pl for pl in data["plugins"] if pl["source"] != "./claude/hooks"]
json.dump(data, open(p, "w"))
EOF
  result=$( bash "$REPO_ROOT/scripts/check-marketplace.sh" "$TEST_TMP/noplugin" 2>&1 || true )
  [[ "$result" == *"FAIL"* ]]
  [[ "$result" == *"curated-hooks.txt has no marketplace plugin"* ]]
}

@test "check-marketplace: plugin missing description fails" {
  mk_fixture "$TEST_TMP/nodesc"
  python3 - "$TEST_TMP/nodesc/.claude-plugin/marketplace.json" <<'EOF'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
del data["plugins"][0]["description"]
json.dump(data, open(p, "w"))
EOF
  result=$( bash "$REPO_ROOT/scripts/check-marketplace.sh" "$TEST_TMP/nodesc" 2>&1 || true )
  [[ "$result" == *"missing description"* ]]
}

@test "check-marketplace: source not starting with ./ fails" {
  mk_fixture "$TEST_TMP/badsource"
  python3 - "$TEST_TMP/badsource/.claude-plugin/marketplace.json" <<'EOF'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
data["plugins"][0]["source"] = {"source": "github", "repo": "x/y"}
json.dump(data, open(p, "w"))
EOF
  result=$( bash "$REPO_ROOT/scripts/check-marketplace.sh" "$TEST_TMP/badsource" 2>&1 || true )
  [[ "$result" == *"must be a relative path starting with ./"* ]]
}

@test "check-marketplace: source path that does not exist fails" {
  mk_fixture "$TEST_TMP/missing"
  python3 - "$TEST_TMP/missing/.claude-plugin/marketplace.json" <<'EOF'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
data["plugins"][0]["source"] = "./claude/nonexistent"
json.dump(data, open(p, "w"))
EOF
  result=$( bash "$REPO_ROOT/scripts/check-marketplace.sh" "$TEST_TMP/missing" 2>&1 || true )
  [[ "$result" == *"does not exist"* ]]
}

teardown() {
  if [[ -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP" 2>/dev/null || true
  fi
}
