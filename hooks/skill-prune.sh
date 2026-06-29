#!/usr/bin/env bash
# skill-prune.sh - telemetry-based skill pruning candidates (P4 skill-auto).
#
# The flip side of progressive disclosure: a catalog that only grows eventually
# drowns relevance. This hook reads the runtime trajectory
# (.harness/runtime/trajectory.jsonl written by trajectory-log.sh) and finds
# skills that are NEVER or RARELY invoked, then STAGES them as prune
# candidates. It never deletes anything - the host agent reviews and archives.
#
# The Wave-5 track converged on this via TAKEOFF69 retrospective + the
# catalog-gardener skill: unmeasured skill catalogs rot. This hook adds the
# telemetry dimension the gardener lacks (the gardener audits structure; this
# audits usage).
#
# What it computes (read-only over trajectory + catalog):
#   1. Build the hit set: skill names seen in tool_input of skill-invocation
#      events in the trajectory (e.g. /<skill-name> patterns, skill_name fields).
#   2. For each skill in the catalog index, classify:
#        - never-hit   : 0 invocations
#        - low-hit     : 1-2 invocations over the log window
#        - active      : >=3 invocations
#   3. Stage never-hit + low-hit as PRUNE CANDIDATES to .harness/forge/.
#
# Usage:
#   hooks/skill-prune.sh                 # scan trajectory, stage prune report
#   hooks/skill-prune.sh --dir <path>   # override the catalog dir
#   hooks/skill-prune.sh --status       # print the last prune report
#
# Exit 0 always (staging is advisory). Pruning = archive, never rm.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
CATALOG="${SKILLS_DIR:-$HOME/.claude/skills}"
TRAJECTORY="$RUNTIME/trajectory.jsonl"
mkdir -p "$RUNTIME" "$FORGE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) CATALOG="$2"; shift 2 ;;
    --status)
      last="$(ls -t "$FORGE"/*-skill-prune.md 2>/dev/null | head -1)"
      [[ -n "$last" ]] || { echo "no prune reports yet"; exit 0; }
      bat -p "$last" 2>/dev/null || cat "$last"
      exit 0 ;;
    *) echo "skill-prune: unknown arg: $1" >&2; exit 2 ;;
  esac
done

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
datestamp="$(date -u +%Y-%m-%d)"

if [[ ! -d "$CATALOG" ]]; then
  echo "skill-prune: catalog dir not found: $CATALOG (set SKILLS_DIR or --dir)" >&2
  exit 0
fi
if [[ ! -s "$TRAJECTORY" ]]; then
  echo "skill-prune: trajectory empty or missing ($TRAJECTORY)." >&2
  echo "  run a session with trajectory-log.sh enabled first; prune candidates need usage data." >&2
  exit 0
fi

report="$FORGE/${datestamp}-skill-prune.md"

# --- Catalog skill names (the universe of candidates) -------------------------
mapfile -t skill_files < <(fd -t f -e md '^SKILL\.md$' "$CATALOG" 2>/dev/null \
  || find "$CATALOG" -type f -name 'SKILL.md' 2>/dev/null)
declare -A skill_present
for f in "${skill_files[@]}"; do
  [[ -f "$f" ]] || continue
  name="$(grep -iE '^name:' "$f" 2>/dev/null | head -1 | sed -E 's/^name:[[:space:]]*//I' | tr -d '"' | tr -d "'")"
  [[ -z "$name" ]] && name="$(basename "$(dirname "$f")")"
  skill_present["$name"]=0
done
total=${#skill_present[@]}

# --- Hit counts from trajectory ----------------------------------------------
# Skill invocations appear as tool calls whose input mentions a skill name.
# We count occurrences of "/<name>" or "\"skill_name\":\"<name>\"" in the log.
# This is a coarse heuristic; it errs toward over-counting (false hits), which
# is the safe direction for a prune CANDIDATE list.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  for name in "${!skill_present[@]}"; do
    if printf '%s' "$line" | grep -qF "/$name"; then
      skill_present["$name"]=$(( ${skill_present["$name"]} + 1 ))
    fi
  done
done < "$TRAJECTORY"

never=0; low=0; active=0
never_list=""; low_list=""
for name in "${!skill_present[@]}"; do
  hits="${skill_present[$name]}"
  if   [[ "$hits" -eq 0 ]]; then never=$((never+1)); never_list="${never_list}- ${name}: 0 hits -> archive candidate\n"
  elif [[ "$hits" -le 2 ]]; then low=$((low+1)); low_list="${low_list}- ${name}: ${hits} hits -> review for retirement\n"
  else active=$((active+1)); fi
done

{
  printf '# Skill prune candidates - %s\n\n' "$ts"
  printf 'Read-only scan of trajectory `%s` against catalog `%s` (%s skills).\n' "$TRAJECTORY" "$CATALOG" "$total"
  printf 'STAGED for host-agent review. Pruning = ARCHIVE, never rm.\n\n'
  printf 'Hit classes: never-hit (0), low-hit (1-2), active (>=3).\n'
  printf 'Caveat: hit detection is a coarse substring heuristic; verify before archiving.\n\n'
  printf '## Summary\n\n'
  printf -- '- total: %s\n' "$total"
  printf -- '- never-hit: %s, low-hit: %s, active: %s\n' "$never" "$low" "$active"
  printf '\n## Never-hit candidates (archive; keep for re-discovery)\n\n'
  if [[ -n "$never_list" ]]; then printf '%b\n' "$never_list"
  else printf 'None. Every skill was invoked at least once.\n\n'; fi
  printf '## Low-hit candidates (review for retirement)\n\n'
  if [[ -n "$low_list" ]]; then printf '%b\n' "$low_list"
  else printf 'None. No skill is in the 1-2 hit band.\n\n'; fi
  printf '## Next\n\n'
  printf -- '- Archive never-hit skills (move to skills/.archive/), do not rm.\n'
  printf -- '- Review low-hit skills: keep if niche-but-valuable, else archive.\n'
  printf -- '- Re-run skill-index.sh after pruning to refresh the catalog.\n'
} > "$report"

printf '{"ts":"%s","event":"skill-prune","total":%s,"never":%s,"low":%s,"active":%s,"report":"%s"}\n' \
  "$ts" "$total" "$never" "$low" "$active" "$report" >> "$RUNTIME/skill-prune.jsonl"

echo "skill-prune: $total skills -> never=$never low=$low active=$active" >&2
echo "  report staged -> $report" >&2
exit 0
