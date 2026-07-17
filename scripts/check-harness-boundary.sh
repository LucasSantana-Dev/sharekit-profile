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
  "claude/skills"
  "hooks"
  "scripts"
)

# Patterns for CODE files (sh/py/js/ts/json/yaml) — full strictness
CODE_PATTERNS=(
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

# Patterns for MARKDOWN files — only actual dependency statements
# (import/require/source/from statements, absolute paths like /Volumes/..., $ROOT references)
MD_PATTERNS=(
  '^\s*import\s+.*\b(src|app|lib)/'
  '^\s*require\s*\([^)]*\b(src|app|lib)/'
  '^\s*source\s+.*\b(src|app|lib)/'
  '^\s*from\s+['\''\"](src|app|lib)/'
  '/Volumes/.*/(src|app|lib)/'
  '\$ROOT/(src|app|lib)/'
)

violations=0
violation_list=""

for dir in "${SCAN_DIRS[@]}"; do
  target="$ROOT/$dir"
  [[ -d "$target" ]] || continue

  # Process non-markdown files with full pattern list
  while IFS= read -r -d '' file; do
    for pattern in "${CODE_PATTERNS[@]}"; do
      if rg -q "$pattern" "$file" 2>/dev/null; then
        relpath="${file#$ROOT/}"
        matches=$(rg -n "$pattern" "$file" 2>/dev/null | head -3)
        violation_list+="  $relpath\n    pattern: $pattern\n    matches:\n"
        while IFS= read -r line; do
          violation_list+="      $line\n"
        done <<< "$matches"
        violation_list+="\n"
        violations=$((violations + 1))
      fi
    done
  done < <(fd -t f -0 -e sh -e py -e js -e ts -e json -e yaml -e yml . "$target" 2>/dev/null)

  # Process markdown files with restricted pattern list (actual dependencies only)
  while IFS= read -r -d '' file; do
    # For .md files, check for actual code dependencies, not generic prose
    for pattern in "${MD_PATTERNS[@]}"; do
      if rg -q "$pattern" "$file" 2>/dev/null; then
        relpath="${file#$ROOT/}"
        matches=$(rg -n "$pattern" "$file" 2>/dev/null | head -3)
        violation_list+="  $relpath\n    pattern: $pattern\n    matches:\n"
        while IFS= read -r line; do
          violation_list+="      $line\n"
        done <<< "$matches"
        violation_list+="\n"
        violations=$((violations + 1))
      fi
    done
  done < <(fd -t f -0 -e md . "$target" 2>/dev/null)
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
