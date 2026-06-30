#!/usr/bin/env bash
# skill-validate.sh - frontmatter schema + security validation gate (P4 skill-auto).
#
# Validates SKILL.md files for schema compliance and security threats before
# they enter the catalog. This is the CI/pre-commit gate that prevents bloat
# and supply-chain risk at ingestion time, complementing skill-index.sh
# (progressive disclosure) and skill-prune.sh (telemetry-based retirement).
#
# Pattern sources: jeremylongshore 8-field rubric + samueltauil two-pass security.
# The security patterns mirror skill-security-scan but in a lightweight shell
# form suitable for CI — no Python/Node dependency.
#
# What it validates (read-only over the catalog):
#   SCHEMA PASS:
#     1. name field present and ≤100 chars
#     2. description field present, >20 chars, ≤500 chars
#     3. description does not contain body content (no markdown headers/code)
#     4. triggers field present with at least 1 entry (warning only)
#     5. invocation_type (if present) is auto|slash|internal
#     6. allow_implicit (if present) is true|false
#   SECURITY PASS:
#     7. No pipe-to-shell installers (curl|sh, wget|bash, etc.)
#     8. No secret exfiltration (sending ~/.ssh, ~/.aws, id_rsa off-host)
#     9. No reverse shell patterns (bash -i >& /dev/tcp, nc -e)
#    10. No prompt-injection lures ("ignore previous instructions")
#
# Usage:
#   hooks/skill-validate.sh                    # validate ~/.claude/skills
#   hooks/skill-validate.sh --dir <path>       # validate a different catalog
#   hooks/skill-validate.sh --status          # print the last validation report
#   hooks/skill-validate.sh --strict          # exit 2 on any finding (for CI)
#
# Exit codes:
#   0 — no critical findings (warnings may exist)
#   2 — critical findings detected (use --strict for warnings too)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
CATALOG="${SKILLS_DIR:-$HOME/.claude/skills}"
STRICT=0
mkdir -p "$RUNTIME" "$FORGE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) CATALOG="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --status)
      last="$(ls -t "$FORGE"/*-skill-validate.md 2>/dev/null | head -1)"
      [[ -n "$last" ]] || { echo "no validation reports yet"; exit 0; }
      bat -p "$last" 2>/dev/null || cat "$last"
      exit 0 ;;
    *) echo "skill-validate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
datestamp="$(date -u +%Y-%m-%d)"

if [[ ! -d "$CATALOG" ]]; then
  echo "skill-validate: catalog dir not found: $CATALOG (set SKILLS_DIR or --dir)" >&2
  echo "  nothing to validate." >&2
  exit 0
fi

report="$FORGE/${datestamp}-skill-validate.md"

# Resolve tool to extract YAML frontmatter fields.
extract_field() {
  # extract_field <file> <field>  (reads simple "field: value" frontmatter)
  grep -iE "^${2}:" "$1" 2>/dev/null | head -1 | sed -E "s/^${2}:[[:space:]]*//I" | tr -d '"' | tr -d "'"
}

mapfile -t skill_files < <(fd -t f -e md '^SKILL\.md$' "$CATALOG" 2>/dev/null \
  || find "$CATALOG" -type f -name 'SKILL.md' 2>/dev/null)

total=${#skill_files[@]}
schema_errors=0
schema_warnings=0
security_critical=0
security_warnings=0
findings=""

for f in "${skill_files[@]}"; do
  [[ -f "$f" ]] || continue
  rel="${f#$CATALOG/}"
  name="$(extract_field "$f" 'name')"
  desc="$(extract_field "$f" 'description')"
  triggers="$(extract_field "$f" 'triggers')"
  inv_type="$(extract_field "$f" 'invocation_type')"
  allow_impl="$(extract_field "$f" 'allow_implicit')"

  # --- SCHEMA PASS -----------------------------------------------------------
  # 1. name present and ≤100 chars
  if [[ -z "$name" ]]; then
    findings="${findings}ERROR  | ${rel} | missing required 'name' field\n"
    schema_errors=$((schema_errors+1))
  elif [[ ${#name} -gt 100 ]]; then
    findings="${findings}ERROR  | ${rel} | name exceeds 100 chars (${#name})\n"
    schema_errors=$((schema_errors+1))
  fi

  # 2. description present, >20 chars, ≤500 chars
  if [[ -z "$desc" ]]; then
    findings="${findings}ERROR  | ${rel} | missing required 'description' field\n"
    schema_errors=$((schema_errors+1))
  elif [[ ${#desc} -lt 20 ]]; then
    findings="${findings}ERROR  | ${rel} | description too short (<20 chars)\n"
    schema_errors=$((schema_errors+1))
  elif [[ ${#desc} -gt 500 ]]; then
    findings="${findings}WARN   | ${rel} | description exceeds 500 chars (${#desc}) — body may be leaking into description\n"
    schema_warnings=$((schema_warnings+1))
  fi

  # 3. description should not contain body content (markdown headers, code blocks)
  if [[ -n "$desc" ]]; then
    if printf '%s' "$desc" | grep -qE '^#|```|^\s*\|'; then
      findings="${findings}WARN   | ${rel} | description contains markdown body content (headers/code/tables)\n"
      schema_warnings=$((schema_warnings+1))
    fi
  fi

  # 4. triggers present (warning only)
  if [[ -z "$triggers" ]]; then
    findings="${findings}WARN   | ${rel} | no 'triggers' field — skill may be undiscoverable\n"
    schema_warnings=$((schema_warnings+1))
  fi

  # 5. invocation_type validation
  if [[ -n "$inv_type" ]] && ! [[ "$inv_type" =~ ^(auto|slash|internal)$ ]]; then
    findings="${findings}WARN   | ${rel} | invalid invocation_type '${inv_type}' (expected: auto|slash|internal)\n"
    schema_warnings=$((schema_warnings+1))
  fi

  # 6. allow_implicit validation
  if [[ -n "$allow_impl" ]] && ! [[ "$allow_impl" =~ ^(true|false)$ ]]; then
    findings="${findings}WARN   | ${rel} | invalid allow_implicit '${allow_impl}' (expected: true|false)\n"
    schema_warnings=$((schema_warnings+1))
  fi

  # --- SECURITY PASS ---------------------------------------------------------
  # Read the full file body (frontmatter + body) for security scanning.
  body="$(cat "$f" 2>/dev/null)"

  # 7. Pipe-to-shell installers
  if printf '%s' "$body" | grep -qiE 'curl\s+[^\|]*\|\s*(sh|bash|zsh)|wget\s+[^\|]*\|\s*(sh|bash|zsh)|curl.*\|\s*sh|wget.*\|\s*bash'; then
    findings="${findings}CRIT   | ${rel} | pipe-to-shell installer detected (curl|sh or wget|bash)\n"
    security_critical=$((security_critical+1))
  fi

  # 8. Secret exfiltration — sending sensitive files off-host
  if printf '%s' "$body" | grep -qiE '\.ssh/id_rsa|\.aws/credentials|\.env\b.*curl|\.env\b.*wget|cat\s+~/.ssh|cat\s+~/\.aws'; then
    findings="${findings}CRIT   | ${rel} | secret exfiltration pattern detected (reading ssh/aws/env + network)\n"
    security_critical=$((security_critical+1))
  fi

  # 9. Reverse shell patterns
  if printf '%s' "$body" | grep -qiE 'bash\s+-i\s+>&\s*/dev/tcp|nc\s+-e|/dev/tcp/|mkfifo.*\|.*nc'; then
    findings="${findings}CRIT   | ${rel} | reverse shell pattern detected\n"
    security_critical=$((security_critical+1))
  fi

  # 10. Prompt-injection lures
  if printf '%s' "$body" | grep -qiE 'ignore previous instructions|ignore all instructions|disregard.*instructions.*and'; then
    findings="${findings}WARN   | ${rel} | prompt-injection lure detected in skill text\n"
    security_warnings=$((security_warnings+1))
  fi

  # 11. Obfuscated execution (base64 decode + exec)
  if printf '%s' "$body" | grep -qiE 'base64\s+-d.*\|\s*(sh|bash|eval)|eval.*base64|echo.*\|\s*base64.*\|\s*sh'; then
    findings="${findings}CRIT   | ${rel} | obfuscated execution detected (base64 decode + exec)\n"
    security_critical=$((security_critical+1))
  fi
done

# --- Report ------------------------------------------------------------------
{
  printf '# Skill validation report - %s\n\n' "$ts"
  printf 'Read-only schema + security scan of `%s` (%s skills).\n' "$CATALOG" "$total"
  printf 'Schema gate: name ≤100, description 20-500 chars, no body in description.\n'
  printf 'Security gate: no pipe-to-shell, secret exfil, reverse shell, obfuscated exec.\n\n'
  printf '## Summary\n\n'
  printf -- '- total skills scanned: %s\n' "$total"
  printf -- '- schema errors: %s\n' "$schema_errors"
  printf -- '- schema warnings: %s\n' "$schema_warnings"
  printf -- '- security critical: %s\n' "$security_critical"
  printf -- '- security warnings: %s\n' "$security_warnings"
  printf '\n## Findings\n\n'
  if [[ -n "$findings" ]]; then
    printf 'Severity | skill | finding\n'
    printf '%s\n' '---------|-------|--------'
    printf '%b' "$findings"
  else
    printf 'No findings. All skills passed schema + security validation.\n'
  fi
  printf '\n## Severity levels\n\n'
  printf -- '- CRIT — security critical: blocks in --strict mode, must fix before merge\n'
  printf -- '- ERROR — schema error: blocks in --strict mode, skill is malformed\n'
  printf -- '- WARN — warning: review recommended, does not block\n'
  printf '\n## Next\n\n'
  printf -- '- Fix CRIT and ERROR findings before merging new/updated skills.\n'
  printf -- '- Review WARN findings for quality improvements.\n'
  printf -- '- Re-run hooks/skill-index.sh after fixes to refresh the catalog index.\n'
} > "$report"

printf '{"ts":"%s","event":"skill-validate","total":%s,"schema_errors":%s,"schema_warnings":%s,"security_critical":%s,"security_warnings":%s,"report":"%s"}\n' \
  "$ts" "$total" "$schema_errors" "$schema_warnings" "$security_critical" "$security_warnings" "$report" >> "$RUNTIME/skill-validate.jsonl"

echo "skill-validate: scanned $total skills (errors=$schema_errors warnings=$schema_warnings critical=$security_critical sec_warn=$security_warnings)" >&2
echo "  report staged -> $report" >&2

# Exit logic: exit 2 on critical findings, or on any finding in --strict mode.
if [[ $security_critical -gt 0 ]] || [[ $schema_errors -gt 0 ]] || { [[ $STRICT -eq 1 ]] && { [[ $schema_warnings -gt 0 ]] || [[ $security_warnings -gt 0 ]]; }; }; then
  exit 2
fi
exit 0
