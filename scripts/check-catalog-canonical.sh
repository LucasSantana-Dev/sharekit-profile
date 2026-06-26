#!/usr/bin/env bash
# Canonical drift-guard (LOCAL ONLY) — ADR-0042.
# Reports SKILLS-array entries that no longer exist in the operator's canonical
# skill set (~/.claude/skills). Catches deletions/renames lingering in the
# showcase (e.g. agent-dispatch after the M9 merge). Cannot run in CI — the
# GitHub Actions runner has no access to ~/.claude/skills — so run it locally
# before pushing, or wire it into a pre-commit hook.
#
# Note: the page is a CURATED PORTFOLIO (ADR-0042) — it intentionally shows a
# subset of canonical. This guard only flags entries that are STALE (on page,
# gone from canonical); it does NOT flag canonical skills missing from the page,
# because omission is a deliberate curation choice.
set -euo pipefail
HTML="${1:-index.html}"
CANON="${2:-$HOME/.claude/skills}"

if [ ! -d "$CANON" ]; then
  echo "SKIP: canonical dir '$CANON' not present (run on the operator machine)."
  exit 0
fi

page=$(awk '/const SKILLS = \[/{f=1} f{print} /^];/{if(f) exit}' "$HTML" \
  | grep -oE "name: '[a-z0-9-]+'" | sed "s/name: '//;s/'$//" | sort -u)
canon=$(ls "$CANON" | sort -u)

stale=$(comm -23 <(printf '%s\n' "$page") <(printf '%s\n' "$canon"))

if [ -n "$stale" ]; then
  echo "STALE showcase entries (listed on page, absent from canonical $CANON):"
  printf '%s\n' "$stale" | sed 's/^/  - /'
  echo ""
  echo "Remove them from the SKILLS array in $HTML (and rerun scripts/check-catalog.sh"
  echo "to refresh counts), or restore the skill if the deletion was unintended."
  exit 1
fi
echo "no stale showcase entries — all $(printf '%s\n' "$page" | grep -c .) page skills exist in canonical"
