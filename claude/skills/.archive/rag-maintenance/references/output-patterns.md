# Signal-First Output Templates

Lead with: **verdict** (index health: HEALTHY | NEEDS_MAINTENANCE | DEGRADED) + **top 3 findings** (if issues exist).

## Example 1: Healthy Index

```
RAG-MAINTENANCE — <github-user>.tech

VERDICT: HEALTHY — 95% of queries score ≥0.55 cosine; no drift detected; corpus complete.

Top findings (of 0 issues):
  (none — index is healthy)

Snapshot: ~/.claude/rag-index/weekly.md
```

## Example 2: Index Needs Maintenance

```
RAG-MAINTENANCE — <github-user>.tech

VERDICT: NEEDS_MAINTENANCE — 18% of queries score <0.40; 8 stale chunks detected; memory vault has 3 new files not yet indexed.

Top findings (of 3 total):
  1. [MEDIUM] 12 zero-hit queries on memory-vault topics (added 2 days ago)
     Fix: Phase 4 will add corpus docs + reindex (Phase 4 — Curate)

  2. [LOW] 8 modified chunks (sha mismatch, stale content in index)
     Fix: Incremental reindex in Phase 4

  3. [LOW] Skills source type at 95% of target (539/500 chunks)
     Status: PASS; no action needed

Remediation plan:
  1. Add missing memory docs (Phase 4: write)
  2. Incremental reindex (Phase 4: build.py --incremental)
  3. Verify zero-hit queries (Phase 4: validation)

Snapshot: ~/.claude/rag-index/weekly.md
Open watch: Check quality again in 7 days; escalate to rebuild if zero-hits persist
```
