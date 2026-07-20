#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0
block() { echo "BLOCKED: $1" >&2; exit 2; }
# Allowlist: template/placeholder files are committed examples with no real
# secrets (gitleaks still scans them). Exempt them BEFORE the protective case so
# .env.example / .env.sample stay editable, while real .env, .env.local,
# .env.production, and key/cert files below remain blocked.
case "$FILE_PATH" in
  *.example|*.sample|*.template|*.dist) exit 0 ;;
esac
case "$FILE_PATH" in
  *"/.env"|*"/.env."*|*"/.credentials.json"|*"/credentials.json"|*"/.git/"*|*"/.ssh/"*|*"/.aws/"*|*"/.gcloud/"*|*"/.npmrc"|*"/id_rsa"|*"/id_ed25519"|*.pem|*.key|*.p12|*.pfx) block "$FILE_PATH is protected or secret-bearing" ;;
  *"claude-mem.db"*|*"claude-mem.db-wal"*|*"claude-mem.db-shm"*) block "$FILE_PATH is a local memory database artifact" ;;
esac
exit 0
