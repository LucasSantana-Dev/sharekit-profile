#!/usr/bin/env bash
# Regression tests for protect-files.sh (PreToolUse Write/Edit guard).
# Feeds REAL JSON envelopes to the actual hook; asserts exit code
# (0 = allow edit, 2 = block). End-to-end: tests the real jq parse + case globs.
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/protect-files.sh"
pass=0; fail=0

env_fp() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }

check() { # desc expected_exit json
  local desc="$1" exp="$2" json="$3" got
  printf '%s' "$json" | "$HOOK" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$exp" ]; then pass=$((pass+1))
  else fail=$((fail+1)); echo "  FAIL: $desc — expected exit $exp, got $got"; fi
}

# --- BLOCK (exit 2): protected / secret-bearing write targets ---
check "dotenv"                 2 "$(env_fp "/Users/x/.env")"
check "dotenv.production"      2 "$(env_fp "/Users/x/.env.production")"
check "credentials.json"       2 "$(env_fp "/Users/x/credentials.json")"
check ".ssh dir"               2 "$(env_fp "/Users/x/.ssh/id_ed25519")"
check ".aws dir"               2 "$(env_fp "/Users/x/.aws/credentials")"
check "npmrc"                  2 "$(env_fp "/Users/x/.npmrc")"
check "id_rsa"                 2 "$(env_fp "/Users/x/id_rsa")"
check "pem"                    2 "$(env_fp "/Users/x/cert.pem")"
check "key"                    2 "$(env_fp "/Users/x/private.key")"
check "p12"                    2 "$(env_fp "/Users/x/bundle.p12")"
check "git internals"          2 "$(env_fp "/Users/x/repo/.git/config")"
check "claude-mem db"          2 "$(env_fp "/Users/x/.claude/claude-mem.db")"
# --- ALLOW (exit 0): templates + normal files + no path ---
check "env.example (safe)"     0 "$(env_fp "/Users/x/.env.example")"
check "env.sample (safe)"      0 "$(env_fp "/Users/x/.env.sample")"
check "template (safe)"        0 "$(env_fp "/Users/x/config.template")"
check "dist (safe)"            0 "$(env_fp "/Users/x/app.dist")"
check "normal source"          0 "$(env_fp "/Users/x/src/index.ts")"
check "readme"                 0 "$(env_fp "/Users/x/README.md")"
check "no file_path"           0 '{"tool_name":"Write","tool_input":{}}'

echo "  protect-files: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
