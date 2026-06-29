#!/usr/bin/env bash
# check-harness-boundary.sh — CI-enforced boundary test.
# Verifies that harness files (skills, agents, standards, hooks, scripts)
# do NOT import or reference project-specific application code.
#
# Harness files must be portable and self-contained. They should not depend
# on src/, app/, or lib/ paths from any specific project.
#
# Exit 0 if clean, exit 1 with list of violations.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Directories to scan (relative to repo root)
SCAN_DIRS=(
  ".claude/skills"
  ".claude/agents"
  ".claude/standards"
  "hooks"
  "scripts"
  "skills"
  "standards"
)

# Patterns that indicate project-specific app code imports
# These are forbidden in harness files — harness must be portable
FORBIDDEN_PATTERNS=(
  'from src[./]'
  'from app[./]'
  'from lib[./]'
  'import src[./]'
  'import app[./]'
  'import lib[./]'
  'require(.src[./]'
  'require(.app[./]'
  'require(.lib[./]'
  'src/[a-zA-Z]'
  'app/[a-zA-Z]'
  'lib/[a-zA-Z]'
  '\.\./src/'
  '\.\./app/'
  '\.\./lib/'
)

violations=0
violation_list=""

for dir in "${SCAN_DIRS[@]}"; do
  target="$ROOT/$dir"
  [[ -d "$target" ]] || continue

  while IFS= read -r -d '' file; do
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
      if grep -qE "$pattern" "$file" 2>/dev/null; then
        relpath="${file#$ROOT/}"
        matches=$(grep -nE "$pattern" "$file" 2>/dev/null | head -3)
        violation_list+="  $relpath\n    pattern: $pattern\n    matches:\n"
        while IFS= read -r line; do
          violation_list+="      $line\n"
        done <<< "$matches"
        violation_list+="\n"
        violations=$((violations + 1))
      fi
    done
  done < <(find "$target" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.md' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
done

if [[ $violations -eq 0 ]]; then
  echo "OK: no project-specific app code references in harness files"
  exit 0
fi

echo "FAIL: $violations file(s) reference project-specific app code:"
echo ""
printf "%b" "$violation_list"
echo "Harness files must be portable. Remove references to src/, app/, lib/ paths."
echo "If the harness needs project context, pass it via arguments or environment,"
echo "not hardcoded imports."
exit 1
