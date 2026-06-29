#!/usr/bin/env bash
# Catalog drift-guard (CI-safe, self-contained) — ADR-0042.
# Fails the build if index.html's DISPLAYED counts disagree with the actual
# SKILLS/AGENTS array lengths or category count. This is the failure mode that
# bit us 2026-06-26 (showed 270 / "162 skills across 22 categories" / 40 agents
# against arrays of 259 / 24 / 39). Runs in GitHub Actions — no local canonical
# needed. For the "page lists a deleted skill" check, see check-catalog-canonical.sh
# (local-only; needs ~/.claude/skills).
set -euo pipefail
HTML="${1:-index.html}"

arr_len() { awk "/const $1 = \[/{f=1} f{print} /^];/{if(f) exit}" "$HTML" | grep -cE "^[[:space:]]*\{[[:space:]]*name:"; }
SKILLS=$(arr_len SKILLS)
AGENTS=$(arr_len AGENTS)
CATS=$(awk '/const SKILLS = \[/{f=1} f{print} /^];/{if(f) exit}' "$HTML" | grep -oE "cat: '[a-z-]+" | sort -u | wc -l | tr -d ' ')

TC_SKILLS=$(grep -oE 'tc-skills">[0-9]+' "$HTML" | grep -oE '[0-9]+' | head -1)
TC_AGENTS=$(grep -oE 'tc-agents">[0-9]+' "$HTML" | grep -oE '[0-9]+' | head -1)
GRID=$(grep -oE '[0-9]+ skills across [0-9]+ categories' "$HTML" | head -1)
GRID_SKILLS=$(printf '%s' "$GRID" | grep -oE '^[0-9]+')
GRID_CATS=$(printf '%s' "$GRID" | grep -oE 'across [0-9]+' | grep -oE '[0-9]+')

fail=0
chk() { # label displayed actual
  if [ "$2" != "$3" ]; then echo "FAIL: $1 shows $2 but actual is $3"; fail=1; fi
}
chk "skills tab-count"      "${TC_SKILLS:-?}"  "$SKILLS"
chk "grid-sub skills"       "${GRID_SKILLS:-?}" "$SKILLS"
chk "grid-sub categories"   "${GRID_CATS:-?}"   "$CATS"
chk "agents tab-count"      "${TC_AGENTS:-?}"   "$AGENTS"

if [ "$fail" = 0 ]; then
  echo "catalog counts consistent: $SKILLS skills, $AGENTS agents, $CATS categories"
fi

# Skill-count guardrail — prevents skill bloat from truncating Claude Code's
# skill listing (skillListingBudgetFraction in ~/.claude/settings.json).
# ~/.codex/skills and ~/.claude/skills both symlink to ~/.agents/skills.
check_skill_count() {
  local dirs=( "$HOME/.agents/skills" "$HOME/.codex/skills" "$HOME/.claude/skills" )
  local count=0
  for d in "${dirs[@]}"; do
    if [ -d "$d" ]; then
      local n
      n=$(find -L "$d" -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' ')
      if [ "$n" -gt "$count" ]; then count=$n; fi
      break
    fi
  done
  if [ "$count" -gt 350 ]; then
    echo "FAIL: skill count $count exceeds 350 — run skill-maintainer to prune duplicates, or raise skillListingBudgetFraction"
    fail=1
  elif [ "$count" -gt 250 ]; then
    echo "WARN: skill count $count exceeds 250 — consider pruning duplicates or raising skillListingBudgetFraction"
  else
    echo "skill count $count within guardrail (warn>250, fail>350)"
  fi
}
check_skill_count

exit "$fail"
