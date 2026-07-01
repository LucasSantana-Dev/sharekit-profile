#!/usr/bin/env bash
# memory-consolidate.sh - sleep-cycle memory consolidation (P4 memory-KG).
#
# The Wave-5 memory/KG track converged on an async "sleep cycle" that runs
# periodically (not per-turn): cluster related facts, compress them into
# higher-order abstractions, promote durable ones, and decay/supersede stale
# ones - WITHOUT ever overwriting history (graphiti supersede-not-overwrite +
# bi-temporal validity windows; agmem versioned memory; hdviettt sleep/wake
# consolidation; apattichis cluster/merge/promote).
#
# This EXTENDS the existing promotion ladder (claude/memory-structure/) - it does
# not add a second memory system. It reads the committed memory/ tier files and
# the runtime trajectory, then STAGES a consolidation report to .harness/forge/.
# Like distill.sh, it NEVER mutates semantic memory directly: the host agent
# reviews and applies via review.sh (graduation requires rationale).
#
# What it computes (read-only over memory/):
#   1. DECAY SCORE per fact = f(age since last_verified, confidence,
#      change_frequency). Stale + low-confidence facts surface as forget
#      candidates (decay, never delete - mark status/archived).
#   2. SUPERSEDE CANDIDATES: facts with overlapping titles/tags where a newer
#      fact contradicts or replaces an older one. Recommends a supersession
#      LINK (old -> new) preserving both, not an overwrite.
#   3. CLUSTERS: groups of related facts that could compress into one
#      higher-order abstraction (promote to a CORE/KB note).
#
# Usage:
#   hooks/memory-consolidate.sh                 # scan memory/, stage a report
#   hooks/memory-consolidate.sh --dir <path>    # override the memory dir
#   hooks/memory-consolidate.sh --status        # print the last report
#
# Exit 0 always (staging is advisory).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
FORGE="$ROOT/.harness/forge"
# Default memory dir: the committed tier files live under memory/ in the live
# harness; fall back to the repo's memory-structure examples for a dry scan.
MEM_DIR="${MEM_DIR:-$ROOT/memory}"
mkdir -p "$RUNTIME" "$FORGE"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
datestamp="$(date -u +%Y-%m-%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) MEM_DIR="$2"; shift 2 ;;
    --status)
      last="$(ls -t "$FORGE"/*-consolidation.md 2>/dev/null | head -1)"
      [[ -n "$last" ]] || { echo "no consolidation reports yet"; exit 0; }
      bat -p --paging=never "$last" 2>/dev/null || sed -n '1,$p' "$last"
      exit 0 ;;
    *) echo "memory-consolidate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$MEM_DIR" ]]; then
  echo "memory-consolidate: memory dir not found: $MEM_DIR (set MEM_DIR or --dir)" >&2
  echo "  nothing to consolidate; the sleep cycle is a no-op until memory/ exists." >&2
  exit 0
fi

report="$FORGE/${datestamp}-consolidation.md"
now_epoch="$(date -u +%s)"

# --- Scan memory facts -------------------------------------------------------
# Each fact file may carry YAML frontmatter: last_verified, confidence,
# change_frequency, tags, status. We parse leniently (missing fields default).
mapfile -t fact_files < <(fd -t f -e md . "$MEM_DIR" 2>/dev/null | sort)

decay_candidates=""
supersede_candidates=""
declare -A tag_index   # tag -> list of files (for clustering)
scanned=0

extract_field() {
  # extract_field <file> <field>  (reads simple "field: value" frontmatter)
  rg -i "^${2}:" "$1" 2>/dev/null | head -1 | sed -E "s/^${2}:[[:space:]]*//I" | tr -d '"'
}

for f in "${fact_files[@]}"; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  # Skip the structural docs (README/CORE/MEGABRAIN/SELF_IMPROVEMENT/TEMPORAL_KG).
  case "$base" in
    README.md|CORE.md|MEGABRAIN.md|SELF_IMPROVEMENT.md|TEMPORAL_KG.md) continue ;;
  esac
  scanned=$((scanned + 1))

  last_verified="$(extract_field "$f" 'last_verified')"
  confidence="$(extract_field "$f" 'confidence')"
  change_freq="$(extract_field "$f" 'change_frequency')"
  tags="$(extract_field "$f" 'tags')"

  # --- Decay score ---
  # age_days since last_verified; if missing, use file mtime.
  if [[ -n "$last_verified" ]]; then
    lv_epoch="$(date -u -j -f '%Y-%m-%d' "${last_verified:0:10}" +%s 2>/dev/null \
      || date -u -d "$last_verified" +%s 2>/dev/null || echo "$now_epoch")"
  else
    lv_epoch="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "$now_epoch")"
  fi
  age_days=$(( (now_epoch - lv_epoch) / 86400 ))

  # confidence defaults to 0.5 if absent; high change_frequency accelerates decay.
  conf="${confidence:-0.5}"
  # Decay heuristic: stale (>90d) AND low confidence (<0.5) => forget candidate.
  if [[ "$age_days" -gt 90 ]] && awk "BEGIN{exit !($conf < 0.5)}" 2>/dev/null; then
    decay_candidates="${decay_candidates}- ${base}: age=${age_days}d confidence=${conf} change_frequency=${change_freq:-?} -> archive (status/archived, do NOT delete)\n"
  fi

  # --- Tag clustering ---
  if [[ -n "$tags" ]]; then
    # tags may be comma- or space-separated.
    for tag in $(printf '%s' "$tags" | tr ',' ' '); do
      [[ -n "$tag" ]] && tag_index["$tag"]="${tag_index[$tag]:-} $base"
    done
  fi
done

# --- Supersede candidates: same title stem, different files ------------------
# Group by the leading token of the filename (a crude title stem). Two files
# sharing a stem are supersede candidates (recommend a link, not an overwrite).
declare -A stem_index
for f in "${fact_files[@]}"; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f" .md)"
  stem="$(printf '%s' "$base" | cut -d- -f1)"
  stem_index["$stem"]="${stem_index[$stem]:-} $base"
done
for stem in "${!stem_index[@]}"; do
  files="${stem_index[$stem]}"
  count="$(printf '%s' "$files" | wc -w | tr -d ' ')"
  if [[ "$count" -gt 1 ]]; then
    supersede_candidates="${supersede_candidates}- stem '${stem}' (${count} files):${files} -> review for supersession LINK (keep both, mark older status/superseded)\n"
  fi
done

# --- Clusters: tags shared by >=2 facts --------------------------------------
clusters=""
for tag in "${!tag_index[@]}"; do
  files="${tag_index[$tag]}"
  count="$(printf '%s' "$files" | wc -w | tr -d ' ')"
  if [[ "$count" -ge 2 ]]; then
    clusters="${clusters}- tag '${tag}' (${count} facts):${files} -> candidate to compress into one higher-order note\n"
  fi
done

# --- Write the staged consolidation report -----------------------------------
{
  printf '# Memory consolidation (sleep cycle) - %s\n\n' "$ts"
  printf 'Read-only scan of `%s` (%s facts). STAGED for host-agent review.\n' "$MEM_DIR" "$scanned"
  printf 'Apply via `hooks/review.sh graduate <id> --rationale "..."`. Never auto-applied.\n\n'
  printf 'Invariants: supersede-not-overwrite (keep history), decay-not-delete\n'
  printf '(archive, never rm), bi-temporal validity (record when a fact stopped\n'
  printf 'being true, do not erase that it once was). See memory-structure/TEMPORAL_KG.md.\n\n'

  printf '## Forget candidates (decay: stale + low confidence)\n\n'
  if [[ -n "$decay_candidates" ]]; then
    printf '%b\n' "$decay_candidates"
  else
    printf 'None. No fact is both >90d stale and <0.5 confidence.\n\n'
  fi

  printf '## Supersede candidates (overlapping title stems)\n\n'
  if [[ -n "$supersede_candidates" ]]; then
    printf '%b\n' "$supersede_candidates"
  else
    printf 'None. No two facts share a title stem.\n\n'
  fi

  printf '## Compression clusters (shared tags)\n\n'
  if [[ -n "$clusters" ]]; then
    printf '%b\n' "$clusters"
  else
    printf 'None. No tag is shared by >=2 facts.\n\n'
  fi

  printf '## Next\n\n'
  printf -- '- Review each candidate; graduate with a rationale or reject.\n'
  printf -- '- Supersession writes a LINK (old -> new) and marks the old fact\n'
  printf -- '  status/superseded; it never deletes the old fact.\n'
  printf -- '- Forgetting marks status/archived; history is retained for\n'
  printf -- '  non-Markovian search.\n'
} > "$report"

printf '{"ts":"%s","event":"memory-consolidation","scanned":%s,"report":"%s"}\n' \
  "$ts" "$scanned" "$report" >> "$RUNTIME/memory-consolidate.jsonl"

echo "memory-consolidate: scanned $scanned facts; report staged -> $report" >&2
echo "  review with: hooks/review.sh list" >&2
exit 0
