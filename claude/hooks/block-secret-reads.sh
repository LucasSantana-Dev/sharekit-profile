#!/usr/bin/env bash
# PreToolUse hook: block reads of secret-bearing files (<project-a>, local-only).
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

# Content check (distinct from the path check above): catches a secret VALUE
# typed directly into the command/pattern text itself (e.g. a Bearer token or
# sk-/ak-/pk- key pasted inline into a curl command) rather than a read of a
# secret-bearing file. Reuses omniroute-mask-secrets.mjs's maskSecret() —
# masking changed the text = a secret-shaped literal was present.
mask_script="$HOME/.claude/scripts/omniroute-mask-secrets.mjs"
content="${f[3]:-} ${f[4]:-}"
if [ -n "${content// /}" ] && command -v node >/dev/null 2>&1 && [ -f "$mask_script" ]; then
    masked="$(printf '%s' "$content" | node "$mask_script" 2>/dev/null || printf '%s' "$content")"
    if [ "$masked" != "$content" ]; then
        echo "BLOCKED: '$tool' command/pattern contains a secret-shaped literal (Bearer token, sk-/ak-/pk- key, or long opaque token). Do not paste credentials directly into tool calls — reference them via an env var or ask the operator." >&2
        exit 2
    fi
fi

# Header-shaped check: catches a secret header VALUE that doesn't match
# maskSecret's shape heuristics (e.g. a short Cookie/Set-Cookie session value —
# "session=abc123" isn't Bearer/sk-/40-char-shaped, so the check above misses
# it), by header NAME instead.
header_script="$HOME/.claude/scripts/omniroute-sanitize-headers.mjs"
if [ -n "${content// /}" ] && command -v node >/dev/null 2>&1 && [ -f "$header_script" ]; then
    header_masked="$(printf '%s' "$content" | node "$header_script" 2>/dev/null || printf '%s' "$content")"
    if [ "$header_masked" != "$content" ]; then
        echo "BLOCKED: '$tool' command/pattern contains a secret-bearing header (Authorization/Cookie/Set-Cookie/X-Api-Key/...) with a real-looking value. Do not paste credentials directly into tool calls — reference them via an env var or ask the operator." >&2
        exit 2
    fi
fi

exit 0
