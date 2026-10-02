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
esac
# Session transcripts and agent memory live in sqlite (claude-mem.db and friends).
# A write there is either corruption or exfiltration, and the -wal/-shm siblings
# carry the same content (2026-08-28).
case "$FILE_PATH" in
  *.db|*.db-wal|*.db-shm|*.sqlite|*.sqlite3|*.sqlite-wal|*.sqlite-shm) block "$FILE_PATH is a database store (session transcripts / secrets at rest)" ;;
esac
exit 0
