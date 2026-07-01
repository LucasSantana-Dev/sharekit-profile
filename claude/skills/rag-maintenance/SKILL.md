---
name: rag-maintenance
description: Keeps the RAG index current by rechunking changed files, retiring dead entries, and re-embedding drifted content.
  Composite RAG maintenance skill — runs a full retrieval index audit end-to-end: measure quality, find corpus gaps, detect stale chunks, and curate (add missing docs, rewrite weak chunks). Chains: rag-quality → adt-rag-coverage → adt-rag-drift → rag-curate. Use when: retrieval is stale/weak, recall scores drop, users report missing docs, or weekly maintenance cycle. Replaces "run four separate RAG skills and hope they talk to each other."
user-invocable: true
auto-invoke: weekly-maintenance + low-relevance-recall-hits + corpus-drift-detected
metadata:
  owner: global-agents
  tier: contextual
---

# RAG Maintenance

Orchestrated end-to-end maintenance for the RAG index. Runs diagnostics → finds gaps → detects drift → curates corpus. Single composite replaces the "guess which RAG skill to run" pattern.

## When to invoke

- **Weekly routine** — scheduled health check on the index
- **Retrieval quality regresses** — users report low-relevance hits, repeated zero-hit queries, stale content returned
- **Corpus gaps detected** — a query that *should* have results returns nothing (cosine <0.25)
- **Drift suspected** — index may contain deleted/orphaned chunks or outdated content
- **After significant file changes** — bulk file edits, repo rewrites, memory vault reorganization
- **Repeated recall failure** — same question asked >2x in a session with low/irrelevant results

## Pair with standards

- `standards/knowledge-brain.md` § 1 — **Mount guard (required):** External HD hosts embedder cache + memory vault
- `standards/skill-quality-spec.md` § 3, 9 — RAG-first discovery patterns
- `~/.claude/rag-index/BENCHMARK.md` — baseline quality metrics (Hit@5, precision)

## Workflow

**Preflight — Mount guard:**
Mount `/Volumes/External HD` is required for all phases (embedder cache, memory vault, canonical chunks). If unmounted: surface blocker loudly; do not attempt RAG operations.

```bash
mount | grep -q "/Volumes/External HD" || { \
  echo "BLOCKED: External HD unmounted — RAG embedder cache + memory vault unreachable"; \
  exit 1; \
}
```

### Phase 1 — Measure retrieval quality
**Integrated former `rag-quality` behavior:** start with `~/.claude/rag-index/weekly.md`; refresh it if older than 7 days. Record zero-hit queries, low-confidence hits, stale chunks, chunk distribution, and quality summary. Run scoped test queries when the report does not answer the current concern.

Score interpretation:
- cosine `<0.25` = zero/near-zero hit; treat as corpus gap or broken scope
- cosine `0.25–0.40` = weak hit; inspect and likely curate
- cosine `0.40–0.55` = usable but should be improved for recurring queries
- cosine `≥0.55` = healthy unless the snippet is semantically wrong

**Feeds into:** Phase 2 (identifies which queries are failing)

**Done when:** Report shows query-score distribution, zero-hit count, stale-chunk count, quality summary table, and any task-specific test query has top-5 results with a judgment (good, weak, wrong, or missing). Baseline exists at `~/.claude/rag-index/weekly.md`.

**Parallelism signal:** Phases 2–3 are independent of each other. After Phase 1 completes, dispatch `adt-rag-coverage` + `adt-rag-drift` in a single message for concurrent execution.

**Skip if:** Report is <24h old and verdict is GOOD (>95% queries ≥0.55 cosine). Proceed to Phase 2 for coverage audit (decoupled from quality).

### Phase 2 — Audit corpus coverage
**Invoke:** `adt-rag-coverage` (distribution by source type: skills, standards, code, handoffs, memory vault, etc.)

**Feeds from:** Phase 1 (context: which retrieval failures to prioritize)

**Feeds into:** Phase 3 (coverage map informs drift scanning scope)

**Done when:** Report shows chunk counts per source type vs targets (skills ≥500, standards ≥50, handoffs ≥200, etc.), identifies underindexed topics.

**Stop if:** Total chunks <5k or any critical source type (skills, standards) below 50% of target → escalate to user: "Corpus is severely depleted; recommend full rebuild before curation pass."

### Phase 3 — Detect stale/orphaned chunks
**Invoke:** `adt-rag-drift` (missing files: deleted since index, modified files: sha mismatch vs current)

**Feeds from:** Phase 2 (coverage map scope)

**Feeds into:** Phase 4 (drift report identifies what to curate, reindex, or drop)

**Done when:** Report lists missing chunks (orphaned files), modified chunks (stale content), drift distribution. Zero drift is pass; N>0 drift flagged for curation.

**Critical guard:** Do NOT delete chunks on an unmounted drive — an absent file during unmount means *unknown* state, not *deleted*. Mount guard in preflight prevents this, but Phase 3 surfaces any unmount-time drift risks explicitly.

### Phase 4 — Curate corpus
**Integrated former `rag-curate` behavior:** choose the smallest repair pattern that addresses the diagnosed gap.

Curation patterns:
- Missing doc: write a short standards/skill/handoff/memory note in the right corpus, then incremental reindex that file.
- Weak retrieval: inspect the returned path/chunk, clarify the source text with the terms users actually query, then reindex and retest.
- Undercovered source: widen index globs only when the files exist and are intentionally part of the corpus.
- Stale/orphaned chunks: reindex modified files; remove deleted-file chunks only after mount guard confirms the filesystem is real, not absent.

Rebuild instead of curate when drift is broad: >100 missing chunks, >20 stale chunks, many tiny chunks under 100 chars, or chunk count drops >5% without a known corpus deletion.

**Feeds from:** Phase 3 (drift report) + Phase 1 (quality gaps) + Phase 2 (coverage targets)

**Feeds into:** final reconciliation

**Done when:** Curation complete:
- Missing docs added to appropriate corpus directory (skills, standards, memory vault)
- Weak chunks rewritten or re-indexed
- Incremental reindex run (or full rebuild if Phase 2 flagged severe depletion)
- Verification run: re-query flagged zero-hit queries, confirm cosine ≥0.25

**Skip if:** Phase 1–3 all report CLEAN (quality good, coverage sufficient, no drift).

## Reconciliation block

```
RAG-MAINTENANCE — <repo/project>

Phase 1 (Quality):       Zero-hits=N, Low-confidence=M, Stale-chunks=K → [OK] DONE
Phase 2 (Coverage):      <total chunks>, skills=X (target 500), standards=Y (target 50) → [OK] DONE | [BLOCKED] DECLINED (skipped: baseline fresh)
Phase 3 (Drift):         Missing=N chunks, Modified=M chunks → [OK] DONE | [BLOCKED] DECLINED (skipped: no drift detected)
Phase 4 (Curate):        Docs added=N, Chunks rewritten=M, Reindex complete → [OK] DONE | [BLOCKED] DECLINED (skipped: all phases CLEAN)

Snapshot:                ~/.claude/rag-index/weekly.md
Open watch:              Weekly: refresh report every 7 days; if zero-hits persist >1 week, escalate to full rebuild audit
```

## Stop / Failure Conditions

**Mount guard failure (Preflight):** `/Volumes/External HD` unmounted → halt all phases, surface blocker, exit with error. Do not attempt RAG operations without the drive mounted.

**Phase 1 quality regressed:** Quality <80% (e.g., >20% queries <0.40 cosine) → surface regression in reconciliation, continue to Phase 2 for root cause (may be drift, may be coverage gap).

**Phase 2 corpus depleted:** Total chunks <5k or critical source (skills/standards) <50% of target → `adt-rag-coverage` flags for escalation; Phase 4 may switch to full rebuild instead of curate.

**Phase 3 drift explosion:** >100 stale chunks or >10% of corpus orphaned → escalate to user: "Drift is severe; recommend full rebuild. Curation (Phase 4) will proceed incrementally but may be inefficient."

**Phase 4 reindex failure:** `build.py` exits with error → surface exit code + stderr; do not claim curation succeeded.

## Strict rules

See `references/constraints.md` for mandatory constraints (no-skip reconciliation, mount-guard deletion guard, Phase-dependency ordering, etc.).

## Signal-first output

See `references/output-patterns.md` for templates (HEALTHY, NEEDS_MAINTENANCE, DEGRADED verdicts with top-3 findings format).

## Auto-chain conditions

- **After Phase 4 (if curation occurred):** Auto-chain `docs-sync` to mirror any new corpus files to `~/.claude/` backups (optional but recommended for durability).
- **If Phase 1–3 all report CLEAN:** Phase 4 skipped; composite output only. No auto-chain needed.

## Configuration

This composite reads no configuration file; it chains the four sub-skills in order. Each sub-skill (rag-quality, adt-rag-coverage, adt-rag-drift, rag-curate) may read its own config if present.

## Evidence & Artifacts

- Phase 1: `~/.claude/rag-index/weekly.md` (quality report)
- Phase 2: Coverage table from Phase 1 report
- Phase 3: Drift summary from Phase 1 report
- Phase 4: Curation log (added docs, reindex timestamps, re-verification cosine scores)
- Reconciliation: Composite signal-first output above
