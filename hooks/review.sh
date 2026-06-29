#!/usr/bin/env bash
# review.sh — host-agent review CLI for staged distill candidates.
#
# The distill STAGES candidates; the host agent (a different session/context —
# evaluator ≠ agent) reviews them via this CLI. Graduation requires an explicit
# --rationale so rubber-stamping is structurally impossible. Rejected candidates
# retain full decision history so recurring churn is visible, not fresh.
#
# Mirrors agentic-stack graduate.py / reject.py / reopen.py.
#
# Usage:
#   hooks/review.sh list                       # list staged candidates by date
#   hooks/review.sh show <date>                # show a forge file's candidates
#   hooks/review.sh graduate <id> --rationale "..." [--confidence 0.8]
#                                              # promote a candidate to semantic memory
#   hooks/review.sh reject <id> --reason "..." # reject (decision history retained)
#   hooks/review.sh reopen <id>                # requeue a rejected candidate
#   hooks/review.sh decisions                  # show the decision log
#
# Semantic memory target respects BRAIN_ROOT (megabrain) then ~/.claude/memory.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$ROOT/.harness/forge"
RUNTIME="$ROOT/.harness/runtime"
DECISIONS="$RUNTIME/review-decisions.jsonl"
MEMORY="${BRAIN_ROOT:-$HOME/.claude/memory}"
mkdir -p "$FORGE" "$RUNTIME" "$MEMORY"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cmd="${1:-list}"; shift || true

die() { echo "review: $*" >&2; exit 1; }

# Extract --rationale / --reason / --confidence from remaining args.
rationale=""; reason=""; confidence=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rationale) shift; rationale="${1:-}"; shift || true ;;
    --reason) shift; reason="${1:-}"; shift || true ;;
    --confidence) shift; confidence="${1:-}"; shift || true ;;
    *) shift ;;
  esac
done

case "$cmd" in
  list)
    [[ -d "$FORGE" ]] || { echo "no staged candidates yet."; exit 0; }
    files="$(find "$FORGE" -name '*-forge.md' -type f 2>/dev/null | sort)"
    [[ -n "$files" ]] || { echo "no staged candidates yet."; exit 0; }
    echo "staged distill candidates:"
    for f in $files; do
      d="$(basename "$f" | sed 's/-forge.md//')"
      n="$(grep -c '^- \[' "$f" 2>/dev/null || echo 0)"
      echo "  $d  ($n candidate(s))  $f"
    done
    ;;

  show)
    [[ -n "${1:-}" ]] || die "show requires a <date>"
    f="$FORGE/${1}-forge.md"
    [[ -f "$f" ]] || die "no forge file for $1"
    cat "$f"
    ;;

  graduate)
    id="${1:-}"
    [[ -n "$id" ]] || die "graduate requires an <id> (date or date#N)"
    [[ -n "$rationale" ]] || die "graduate requires --rationale \"...\" (no rubber-stamping)"
    conf="${confidence:-0.8}"
    # For now, graduate by date: write a graduated lesson file.
    datepart="${id%%#*}"
    src="$FORGE/${datepart}-forge.md"
    [[ -f "$src" ]] || die "no forge file for $datepart"
    slug="lesson_${datepart}"
    dest="$MEMORY/${slug}.md"
    {
      printf -- '---\n'
      printf 'name: %s\n' "$slug"
      printf 'description: Graduated lesson from %s distill (reviewer rationale below).\n' "$datepart"
      printf 'metadata:\n'
      printf '  type: feedback\n'
      printf '  last_verified: %s\n' "$datepart"
      printf '  change_frequency: medium\n'
      printf '  confidence: %s\n' "$conf"
      printf -- '---\n\n'
      cat "$src"
      printf '\n\n## Graduation\n\n'
      printf -- '- **reviewer_rationale:** %s\n' "$rationale"
      printf -- '- **graduated_at:** %s\n' "$ts"
      printf -- '- **source:** %s\n' "$src"
    } > "$dest"
    printf '{"ts":"%s","event":"graduate","id":"%s","rationale":"%s","confidence":%s,"dest":"%s"}\n' \
      "$ts" "$id" "$rationale" "$conf" "$dest" >> "$DECISIONS"
    echo "graduated $id → $dest"
    echo "  update MEMORY.md index if this should be Tier-1 loaded."
    ;;

  reject)
    id="${1:-}"
    [[ -n "$id" ]] || die "reject requires an <id>"
    [[ -n "$reason" ]] || die "reject requires --reason \"...\" (decision history retained)"
    printf '{"ts":"%s","event":"reject","id":"%s","reason":"%s"}\n' \
      "$ts" "$id" "$reason" >> "$DECISIONS"
    echo "rejected $id (decision history retained in $DECISIONS)"
    ;;

  reopen)
    id="${1:-}"
    [[ -n "$id" ]] || die "reopen requires an <id>"
    printf '{"ts":"%s","event":"reopen","id":"%s"}\n' "$ts" "$id" >> "$DECISIONS"
    echo "reopened $id — it will be re-mined on the next distill run."
    ;;

  decisions)
    [[ -f "$DECISIONS" ]] || { echo "no review decisions yet."; exit 0; }
    cat "$DECISIONS"
    ;;

  *)
    die "unknown command: $cmd (use list|show|graduate|reject|reopen|decisions)"
    ;;
esac
exit 0
