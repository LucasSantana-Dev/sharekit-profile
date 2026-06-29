#!/usr/bin/env bash
# skill-index.sh - progressive-disclosure skill catalog index (P4 skill-auto).
#
# The Wave-5 skill-auto track converged on a 4-tier progressive disclosure
# (microsoft tiered skill loading + openai/codex metadata-only preload +
# TAKEOFF69 retrospective). The failure mode it prevents: load-all skills into
# context every session -> at 200+ skills the listing itself eats 5-15% of the
# window before any real work starts, and truncation silently drops skills.
#
# This hook builds a METADATA-ONLY index: for each skill it captures only
# name + description + triggers + size class, NEVER the body. The host agent
# loads the index (cheap), decides which skill is relevant, and then loads
# that one skill's body on demand. This is the analogue of tool shortlisting
# (P3 tool-shortlist.sh) applied to the skill catalog.
#
# What it does (read-only over the catalog):
#   1. Walk SKILL.md files under the catalog dir (default ~/.claude/skills).
#   2. Parse frontmatter: name, description, triggers.
#   3. Classify size: tiny (<2KB), small (2-4KB), medium (4-8KB), large (>8KB).
#   4. Emit a compact index line per skill to .harness/forge/skill-index.md.
#
# Usage:
#   hooks/skill-index.sh                    # index ~/.claude/skills
#   hooks/skill-index.sh --dir <path>       # index a different catalog
#   hooks/skill-index.sh --status          # print the last index
#
# Exit 0 always (indexing is advisory).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
CATALOG="${SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$RUNTIME" "$FORGE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) CATALOG="$2"; shift 2 ;;
    --status)
      last="$(ls -t "$FORGE"/*-skill-index.md 2>/dev/null | head -1)"
      [[ -n "$last" ]] || { echo "no skill index yet"; exit 0; }
      bat -p "$last" 2>/dev/null || cat "$last"
      exit 0 ;;
    *) echo "skill-index: unknown arg: $1" >&2; exit 2 ;;
  esac
done

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
datestamp="$(date -u +%Y-%m-%d)"

if [[ ! -d "$CATALOG" ]]; then
  echo "skill-index: catalog dir not found: $CATALOG (set SKILLS_DIR or --dir)" >&2
  echo "  nothing to index; progressive disclosure is a no-op until a catalog exists." >&2
  exit 0
fi

report="$FORGE/${datestamp}-skill-index.md"
# Resolve tool to extract YAML frontmatter fields. jq is already a hard dep of
# the harness (trajectory-log.sh); fall back to grep if absent.
extract_field() {
  # extract_field <file> <field>  (reads simple "field: value" frontmatter)
  grep -iE "^${2}:" "$1" 2>/dev/null | head -1 | sed -E "s/^${2}:[[:space:]]*//I" | tr -d '"' | tr -d "'"
}

mapfile -t skill_files < <(fd -t f -e md '^SKILL\.md$' "$CATALOG" 2>/dev/null \
  || find "$CATALOG" -type f -name 'SKILL.md' 2>/dev/null)

total=${#skill_files[@]}
tiny=0; small=0; medium=0; large=0
rows=""

for f in "${skill_files[@]}"; do
  [[ -f "$f" ]] || continue
  name="$(extract_field "$f" 'name')"
  [[ -z "$name" ]] && name="$(basename "$(dirname "$f")")"
  desc="$(extract_field "$f" 'description')"
  triggers="$(extract_field "$f" 'triggers')"
  # triggers may be a YAML list; collapse to a compact string.
  triggers="$(printf '%s' "$triggers" | tr -d '[]' | tr -s ' ' | head -c 120)"
  [[ -z "$desc" ]] && desc="(no description)"
  # Size class from file bytes.
  bytes="$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null || echo 0)"
  if   [[ "$bytes" -lt 2048 ]];  then class="tiny";   tiny=$((tiny+1))
  elif [[ "$bytes" -lt 4096 ]];  then class="small";  small=$((small+1))
  elif [[ "$bytes" -lt 8192 ]];  then class="medium"; medium=$((medium+1))
  else                            class="large";  large=$((large+1))
  fi
  # One compact row: name | class | desc (truncated) | triggers (truncated)
  desc_short="$(printf '%s' "$desc" | head -c 80)"
  rows="${rows}| ${name} | ${class} | ${desc_short} | ${triggers}\n"
done

{
  printf '# Skill catalog index - %s\n\n' "$ts"
  printf 'METADATA-ONLY index of `%s` (%s skills). Bodies are NOT loaded here.\n' "$CATALOG" "$total"
  printf 'Progressive disclosure: load this index, then load ONE skill body on demand.\n\n'
  printf 'Size classes: tiny <2KB, small 2-4KB, medium 4-8KB, large >8KB.\n'
  printf 'WARN: large skills (>8KB) are candidates to split into references/.\n'
  printf 'WARN: at >250 skills consider skill-prune.sh to retire low-hit skills.\n\n'
  printf '## Summary\n\n'
  printf -- '- total: %s\n' "$total"
  printf -- '- tiny: %s, small: %s, medium: %s, large: %s\n' "$tiny" "$small" "$medium" "$large"
  printf '\n## Catalog (name | size | description | triggers)\n\n'
  printf '| name | size | description | triggers |\n'
  printf '|------|------|-------------|----------|\n'
  printf '%b' "$rows"
  printf '\n## Next\n\n'
  printf -- '- Load only the skill body you need; do not load-all.\n'
  printf -- '- Run hooks/skill-prune.sh to find low-hit pruning candidates from trajectory.\n'
} > "$report"

printf '{"ts":"%s","event":"skill-index","total":%s,"tiny":%s,"small":%s,"medium":%s,"large":%s,"report":"%s"}\n' \
  "$ts" "$total" "$tiny" "$small" "$medium" "$large" "$report" >> "$RUNTIME/skill-index.jsonl"

echo "skill-index: indexed $total skills (tiny=$tiny small=$small medium=$medium large=$large)" >&2
echo "  index staged -> $report" >&2
exit 0
