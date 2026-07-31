#!/usr/bin/env bash
# review-tier.sh - deterministic PR risk-tier classifier + review-context
# builder (spec: .claude/plans/spec-ci-review-pack.md, D2 tiering, D4 noise
# pre-filter, D6 shared context file).
#
# Input:
#   review-tier.sh            read a diff summary on stdin: either a unified
#                             patch (git diff / gh pr diff --patch output) or
#                             numstat lines ("<added>\t<deleted>\t<path>").
#   review-tier.sh <PR>       fetch the diff for PR number <PR> via
#                             `gh pr diff <PR> --name-only` (file list) plus
#                             `gh pr diff <PR> --patch` (counts + context).
#
# Output (stdout, key=value): tier, coordinator_model, coordinator_downgraded,
# reviewers, files, lines, reviewable_files, context_dir.
# Also writes $REVIEW_CONTEXT_DIR (default ./review-context): one patch file
# per reviewable file under files/ plus a shared context.txt.
set -euo pipefail

# ---------------------------------------------------------------------------
# Thresholds (spec D2; spec open question 2: tune in ONE place, here only).
# ---------------------------------------------------------------------------
TRIVIAL_MAX_LINES=10   # <= this many changed lines ...
TRIVIAL_MAX_FILES=20   # ... AND <= this many files -> trivial
LITE_MAX_LINES=100     # <= this many changed lines ...
LITE_MAX_FILES=20      # ... AND <= this many files -> lite
FULL_MIN_FILES=50      # > this many files -> full, regardless of line count
# Paths that always force a full review, whatever the diff size (spec D2).
SECURITY_PATH_RE='(^|/)(auth|crypto)/|secret|credential'
# Noise pre-filter for review-context (spec D4: lockfiles, .min.*, .map,
# @generated). Migration files are exempt and ALWAYS kept (spec D2 note).
NOISE_PATH_RE='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$|\.min\.[^/]+$|\.map$'
MIGRATION_PATH_RE='(^|/)migrations?/|(^|/|_)(migrate|migration)(_|/|\.)'

# Model mapping (spec D3; tiers per .harness/llm-policy.json). Coordinator
# runs on the strongest model, downgraded one tier for trivial PRs.
COORDINATOR_MODEL_FULL="anthropic/claude-opus-4-8"
COORDINATOR_MODEL_TRIVIAL="anthropic/claude-sonnet-4-5"

OUT_DIR="${REVIEW_CONTEXT_DIR:-review-context}"
PR="${1:-}"

TMP_FILES="$(mktemp -d)"
trap 'rm -rf "$TMP_FILES"' EXIT
RAW="$TMP_FILES/raw.diff"
ENTRIES="$TMP_FILES/entries.tsv"

if [ -n "$PR" ]; then
  command -v gh >/dev/null 2>&1 || { echo "FAIL: gh CLI required for PR mode" >&2; exit 1; }
  gh pr diff "$PR" --name-only > "$TMP_FILES/names.txt"
  gh pr diff "$PR" --patch > "$RAW"
else
  cat > "$RAW"
fi

# Parse the input into TSV entries: idx, added, deleted, generated, path.
# Patch mode also writes one chunk file per diffed file into $TMP_FILES.
if grep -q '^diff --git ' "$RAW"; then
  MODE="patch"
  awk -v tmp="$TMP_FILES" '
    {
      if ($0 ~ /^diff --git /) {
        if (have) flush()
        idx++; have=1; add=0; del=0; gen=0; path=""
        n=split($0, p, " b/"); bpath=p[n]
        out=sprintf("%s/p%06d.patch", tmp, idx)
      }
      if (have) print $0 >> out
      if ($0 ~ /^\+\+\+ b\//) path=substr($0, 7)
      else if ($0 ~ /^\+/ && $0 !~ /^\+\+\+/) add++
      else if ($0 ~ /^-/ && $0 !~ /^---/) del++
      if ($0 ~ /@generated/) gen=1
    }
    END { if (have) flush() }
    function flush() {
      if (path == "") path=bpath
      printf "%d\t%d\t%d\t%d\t%s\n", idx, add, del, gen, path
    }
  ' "$RAW" > "$ENTRIES"
else
  MODE="numstat"
  awk '
    {
      line=$0
      if (line !~ /^[0-9-]/) next
      n=split(line, f, /\t/)
      if (n >= 3) {
        add=f[1]; del=f[2]
        sub(/^[^\t]*\t[^\t]*\t/, "", line); path=line
      } else {
        m=split(line, g, /[ \t]+/)
        if (m < 3) next
        add=g[1]; del=g[2]; path=g[3]
      }
      if (add !~ /^[0-9]+$/) add=0
      if (del !~ /^[0-9]+$/) del=0
      if (path == "") next
      idx++
      printf "%d\t%d\t%d\t0\t%s\n", idx, add, del, path
    }
  ' "$RAW" > "$ENTRIES"
fi

# PR mode: merge --name-only entries missing from the patch (mode-only or
# rename changes produce no patch hunks) with zero line counts.
if [ -n "$PR" ] && [ -s "$TMP_FILES/names.txt" ]; then
  MAXIDX=$(awk -F'\t' 'BEGIN{m=0}{if($1>m)m=$1}END{print m+0}' "$ENTRIES")
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    if ! awk -F'\t' -v p="$name" '$5==p{f=1} END{exit !f}' "$ENTRIES"; then
      MAXIDX=$((MAXIDX+1))
      printf '%d\t0\t0\t0\t%s\n' "$MAXIDX" "$name" >> "$ENTRIES"
    fi
  done < "$TMP_FILES/names.txt"
fi

# Classification (spec D2). Order matters: full overrides everything.
FILES=0; LINES=0; SECURITY=0
while IFS=$'\t' read -r _idx add del _gen path; do
  FILES=$((FILES+1))
  LINES=$((LINES+add+del))
  if [[ "$path" =~ $SECURITY_PATH_RE ]]; then SECURITY=1; fi
done < "$ENTRIES"

if [ "$FILES" -gt "$FULL_MIN_FILES" ] || [ "$SECURITY" -eq 1 ]; then
  TIER="full"
elif [ "$LINES" -le "$TRIVIAL_MAX_LINES" ] && [ "$FILES" -le "$TRIVIAL_MAX_FILES" ]; then
  TIER="trivial"
elif [ "$LINES" -le "$LITE_MAX_LINES" ] && [ "$FILES" -le "$LITE_MAX_FILES" ]; then
  TIER="lite"
else
  TIER="full"
fi

case "$TIER" in
  trivial)
    REVIEWERS="general"
    COORDINATOR="$COORDINATOR_MODEL_TRIVIAL"
    DOWNGRADED="true"
    ;;
  lite)
    REVIEWERS="general,security,docs"
    COORDINATOR="$COORDINATOR_MODEL_FULL"
    DOWNGRADED="false"
    ;;
  full)
    REVIEWERS="general,security,quality,docs"
    COORDINATOR="$COORDINATOR_MODEL_FULL"
    DOWNGRADED="false"
    ;;
esac

# Build review-context (spec D6): per-file patches + one shared context file.
# Noise paths are dropped, migration files are always kept.
[ -d "$OUT_DIR" ] && rm -rf -- "${OUT_DIR:?OUT_DIR must not be empty}"
mkdir -p "$OUT_DIR/files"
REVIEWABLE=0
REVIEWABLE_TSV="$TMP_FILES/reviewable.tsv"
: > "$REVIEWABLE_TSV"
while IFS=$'\t' read -r idx add del gen path; do
  keep=1
  if [[ "$path" =~ $MIGRATION_PATH_RE ]]; then
    keep=1
  elif [[ "$path" =~ $NOISE_PATH_RE ]] || [ "$gen" = "1" ]; then
    keep=0
  fi
  if [ "$keep" = "1" ]; then
    REVIEWABLE=$((REVIEWABLE+1))
    printf '%s\t+%s -%s\n' "$path" "$add" "$del" >> "$REVIEWABLE_TSV"
    if [ "$MODE" = "patch" ]; then
      safe=$(printf '%s' "$path" | tr '/ ' '__')
      mv "$TMP_FILES/$(printf 'p%06d' "$idx").patch" "$OUT_DIR/files/$safe.patch"
    fi
  fi
done < "$ENTRIES"

{
  echo "# Shared review context (spec D6: one context file per PR)"
  echo "tier=$TIER"
  echo "coordinator_model=$COORDINATOR"
  echo "coordinator_downgraded=$DOWNGRADED"
  echo "reviewers=$REVIEWERS"
  echo "files=$FILES"
  echo "lines=$LINES"
  echo "reviewable_files=$REVIEWABLE"
  if [ "$MODE" != "patch" ]; then
    echo "note=numstat input: per-file patch bodies not available"
  fi
  echo ""
  echo "## Reviewable files (noise pre-filtered; migrations always kept)"
  while IFS=$'\t' read -r path stats; do
    echo "- $path ($stats)"
  done < "$REVIEWABLE_TSV"
} > "$OUT_DIR/context.txt"

printf 'tier=%s\n' "$TIER"
printf 'coordinator_model=%s\n' "$COORDINATOR"
printf 'coordinator_downgraded=%s\n' "$DOWNGRADED"
printf 'reviewers=%s\n' "$REVIEWERS"
printf 'files=%s\n' "$FILES"
printf 'lines=%s\n' "$LINES"
printf 'reviewable_files=%s\n' "$REVIEWABLE"
printf 'context_dir=%s\n' "$OUT_DIR"
