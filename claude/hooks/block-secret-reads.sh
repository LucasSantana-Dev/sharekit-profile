#!/usr/bin/env bash
# PreToolUse hook: block reads of secret-bearing files (Lucky, local-only).
# Rationale: 2026-05-31 a secret file was read into the transcript, leaking keys.
# Blocks Read/Grep/Bash access to ~/.zshrc, secrets.zsh, .env*, *.pem, id_*.
# Exit 2 = deny (message on stderr -> shown to model). Exit 0 = allow.
set -euo pipefail

payload="$(cat)"

# Extract the fields we care about without requiring jq.
field() { printf '%s' "$payload" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); ti=d.get('tool_input',{})
    print(d.get('tool_name',''))
    print(ti.get('file_path',''))
    print(ti.get('path',''))
    print(ti.get('command',''))
    print(ti.get('pattern',''))
except Exception:
    pass" 2>/dev/null; }

mapfile -t f < <(field)
tool="${f[0]:-}"; haystack="${f[1]:-} ${f[2]:-} ${f[3]:-} ${f[4]:-}"

# Secret-bearing path patterns (extended regex). Covers shell rc/profile, .env,
# private keys, npm/netrc, and cloud credential stores (AWS / GCP / kube / docker).
secret_re='(^|/|[[:space:]])(\.zshrc|\.zprofile|\.bash_profile|\.bashrc)|secrets\.zsh|(^|/)\.env([.][^/[:space:]]+)?([[:space:]]|$)|\.pem([[:space:]]|$)|(^|/)id_(rsa|ed25519|ecdsa)|\.netrc|\.npmrc|(^|/)\.aws/(credentials|config)|(^|/)\.kube/config|(^|/)\.config/gcloud/[^[:space:]]*credentials|(^|/)\.docker/config\.json'

# Safe templates carry placeholder values, not real secrets — allow them.
safe_re='\.env\.(example|sample|template|dist|defaults)([.][^/[:space:]]+)?([[:space:]]|/|$)'

if printf '%s' "$haystack" | grep -qE "$safe_re"; then
    exit 0
fi

if printf '%s' "$haystack" | grep -qE "$secret_re"; then
    echo "BLOCKED: '$tool' targets a secret-bearing file. Reading it would leak credentials into the transcript (see ~/.claude/standards/shell-secret-management.md). If you genuinely need a value, ask the operator to provide it — do not read the file." >&2
    exit 2
fi
exit 0
