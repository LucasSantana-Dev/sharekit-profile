#!/usr/bin/env bash
# Regression tests for block-secret-reads.sh.
# Feeds REAL JSON envelopes to the actual hook and asserts its exit code
# (0 = allow, 2 = block). Tests the real artifact end-to-end — stdin parse +
# regex — so it cannot drift from a copied-out regex. Run via run-tests.sh
# (the runner's `bash <path>` invocation keeps secret-path literals out of any
# PreToolUse command-text scan; the hook only sees this subprocess's stdin).
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/block-secret-reads.sh"
pass=0; fail=0

env_fp()  { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
env_cmd() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
env_pat() { printf '{"tool_name":"Grep","tool_input":{"pattern":"%s","path":"%s"}}' "$1" "$2"; }

check() { # desc expected_exit json
  local desc="$1" exp="$2" json="$3" got
  printf '%s' "$json" | "$HOOK" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$exp" ]; then pass=$((pass+1))
  else fail=$((fail+1)); echo "  FAIL: $desc — expected exit $exp, got $got"; fi
}

# --- BLOCK (exit 2): cloud credential stores (added 2026-06-26, SEC-001) ---
check "aws credentials"        2 "$(env_fp Read "/Users/x/.aws/credentials")"
check "aws config"             2 "$(env_fp Read "/Users/x/.aws/config")"
check "kube config"            2 "$(env_fp Read "/Users/x/.kube/config")"
check "gcloud ADC"             2 "$(env_fp Read "/home/u/.config/gcloud/application_default_credentials.json")"
check "docker config"          2 "$(env_fp Read "/Users/x/.docker/config.json")"
# --- BLOCK: original patterns (regression guard) ---
check "zshrc"                  2 "$(env_fp Read "/Users/x/.zshrc")"
check "dotenv"                 2 "$(env_fp Read "/Users/x/.env")"
check "dotenv.local"           2 "$(env_fp Read "/Users/x/.env.local")"
check "pem key"                2 "$(env_fp Read "/Users/x/server.pem")"
check "id_rsa"                 2 "$(env_fp Read "/Users/x/id_rsa")"
check "npmrc"                  2 "$(env_fp Read "/Users/x/.npmrc")"
check "secret via bash cat"    2 "$(env_cmd "cat /Users/x/.env")"
check "secret via grep path"   2 "$(env_pat "KEY" "/Users/x/.aws/credentials")"
# --- ALLOW (exit 0): safe files + false-positive guards ---
check "readme"                 0 "$(env_fp Read "/Users/x/README.md")"
check "package.json"           0 "$(env_fp Read "/Users/x/package.json")"
check "env.example (safe)"     0 "$(env_fp Read "/Users/x/.env.example")"
check "env.sample (safe)"      0 "$(env_fp Read "/Users/x/.env.sample")"
check "aws-client source"      0 "$(env_fp Read "/Users/x/src/aws-client.ts")"
check "kubeconfig docs"        0 "$(env_fp Read "/Users/x/kubeconfig-docs.md")"
check "empty payload"          0 "{}"

echo "  block-secret-reads: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
