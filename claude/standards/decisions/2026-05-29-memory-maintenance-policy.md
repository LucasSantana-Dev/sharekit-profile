# Memory maintenance policy — purge transient, defer decay

- Date: 2026-05-29
- Status: Accepted — transient purge **EXECUTED 2026-05-29** (operator-approved)
- Pipeline: `/research-and-decide` (2 grounding agents → critic → **direct verification** → this ADR)

## Context

The memory layer = **587 markdown notes** across 11 project dirs (`~/.claude/projects/*/memory/`) + claude-mem (FTS5) + MEMORY.md indexes. Retrieval utility is measurable via `queries.sqlite` (4.0M, ~9.5k queries, logs `top_path`). T5 ("dedup + decay") was hard-gated as destructive.

**A contradiction had to be resolved before acting:** the critic returned "REJECT — fabricated data" (claiming 152 notes / 0 precompact snapshots / no queries.sqlite). Direct verification proved the **grounding correct**: 587 notes, **208 `precompact_snapshot`**, 11 `session_end`, queries.sqlite present, 14 ADR-number files across 5 numbers. The critic had scoped to a single project dir + the wrong queries.sqlite path. Its counts were wrong — but its *policy* cautions were sound and are adopted.

Key facts: 78% of notes never-retrieved, BUT 80% are <30 days old (recently created); age-decay candidates (>90d + never + non-critical) = only **2–3**; critical-but-stale RISK set = **0**.

## Decision

1. **PURGE transient ephemera** (gated): the 208 `precompact_snapshot_*` + 11 `session_end_*` — **age-scoped to EXCLUDE the current/active session's snapshots** (recovery risk), **backup to a tarball first**, then validate the RAG eval is unchanged. ~37% sprawl reduction at near-zero risk (true ephemera). HARD-GATED on operator OK.
2. **REJECT merging the 14 ADR-number files.** They are number *reuse across different projects/topics* (3 distinct ADR-0003s, etc.), NOT duplicates — merging would conflate distinct decisions. Leave them; disambiguate only a genuine same-dir collision (none confirmed). [critic's valid catch]
3. **DEFER age-based decay** — only 2–3 candidates; trivial; RISK set = 0.
4. **DEFER decaying the 397 recent never-retrieved** — too new to judge utility; decaying now is the survivorship-bias trap (pre-mortem).
5. **DEFER MEMORY.md index regeneration** — it's ~99% drifted, but manual regen re-drifts within weeks; needs an automated TOC job (separate decision). Rely on RAG/`recall` for discovery meanwhile.

## Alternatives considered

- Merge ADR collisions — REJECTED (number-reuse ≠ duplicate; conflates decisions).
- Age-decay all never-retrieved — REJECTED (80% are <30d; survivorship bias).
- Manual MEMORY.md index rebuild — REJECTED (re-drifts; automate instead).
- Do nothing — REJECTED (the transient purge is a real, safe 37% win).

## Consequences

- (+) ~37% sprawl cut from transient purge; cleaner memory dir; lower index/scan noise.
- (−) Real-note utility-decay deferred (acceptable — measure-first; the data to decay *safely* isn't mature yet).
- (~) ADR number-reuse left as-is (low risk; per-project namespaces).
- (lesson) Memory counts MUST scope to ALL `~/.claude/projects/*/memory/` dirs; `queries.sqlite` lives at `~/.claude/rag-index/`. A reviewer that mis-scopes will false-flag "fabrication" — verify directly.

## Revisit when

- **2026-06-28 (30d)**: measure recent-note retrieval utility from `queries.sqlite`; decay real notes only on PROVEN non-use, not age.
- Precompact snapshots re-accumulate (>50) → repeat the (now-defined) transient purge.
- An automated MEMORY.md TOC job is built → close the index-drift defer.

## Execution result (2026-05-29, operator-approved)

- **Backup first**: full memory tree (590 files) → `${DEV_ROOT}/.memory-backups/memory-full-2026-05-29.tar.gz` (632 K). Restore: `tar xzf <tarball> -C /`. Delete-targets verified present in backup before deletion.
- **Purged**: exactly 219 transient files (208 `precompact_snapshot_*` + 11 `session_end_*`). Notes **587 → 368** (−37%), residual transient = 0, zero collateral (removed == delete-set).
- **Validated**: RAG eval **unchanged** — `MRR=0.47 / hit@1=0.408 / hit@3=0.531 / hit@5=0.573` (identical to pre-merge baseline). Only 1 deleted file was in the RAG-indexed dir → 1 stale chunk of 8,372, auto-cleared by the sessionstart drift-reindex hook.
- **Repeatable**: this is now the defined transient-purge op — re-run when `precompact_snapshot_*` count exceeds ~50.
