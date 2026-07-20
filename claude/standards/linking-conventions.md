# Linking Conventions (memories, ADRs, knowledge-brain docs)

Operator mantra (2026-07-09): **the more connections, the better it will work** — refined by evidence
to: more *meaningful* connections, selectively. Retrieval research is blunt: selective linking wins;
exhaustive linking adds index bloat and spreading-activation noise (GraphRAG-Bench arXiv:2506.02404 —
12× indexing cost; unbiased eval arXiv:2506.06331 — claimed 66.7% win rate drops to 39% measured;
HippoRAG arXiv:2410.05779 — link gains need query-time PageRank, not static links). At our scale
(~21k chunks, e5-small) the ranker is the bottleneck (ADR-0045), so links serve navigation,
staleness-tracing, and future neighbor-expansion — not ranking. Write for signal, not count.

## Rules for every new memory / knowledge doc

1. **≥1 real link, ≤5 total.** Before writing, scan the project's MEMORY.md index for neighbors;
   link the load-bearing ones with `[[name]]` (the target's frontmatter `name:` slug). A link to a
   not-yet-written note is allowed (it marks a gap) but must be plausible, not decorative.
   Zero links = orphan (validator warns). More than ~5 = noise (evidence-based gate).
2. **Name entities explicitly** in prose: ADR numbers (`ADR-0051`), skill names, file paths,
   repo names, incident dates. Shared entities are implicit retrieval edges — cheaper and more
   robust than any link syntax.
3. **Bidirectional only when load-bearing.** If a new note supersedes/resolves/refines an existing
   one, update the OLD note's status line to point forward. Don't backfill reciprocal links for
   mere mentions.
4. **Enrich, don't orphan.** Prefer updating an existing connected note over spawning a new
   near-duplicate. New note only for a genuinely new fact.
5. **Typed relations for ADRs** (already practiced — keep): `Supersedes:` / `Builds on:` /
   `Refines:` header lines naming prior ADRs. Memories citing decisions name the ADR number.
6. **Machine-greppable staleness.** Any follow-up/expiry gets an explicit line:
   `re-check: YYYY-MM-DD — <what to verify>`. Resolved items flip to `RESOLVED YYYY-MM-DD` in the
   description. This is what audits grep; prose like "check back around mid July" is invisible.
7. **Hub notes.** Each project's MEMORY.md is its hub — every memory gets its one-line indexed
   entry with 1-2 `[[links]]` in the hook text. No separate MOC files (index bloat).

## Validator

`~/.claude/scripts/memory-link-check.sh <memory-dir>` — read-only reporter: orphans (zero
`[[links]]`), dangling `[[targets]]` (no matching `name:` slug in the dir), passed `re-check:` dates.
Run via `/memory-prune`, `/sync-memories` close-out, or ad hoc. Warns, never blocks — memory capture
must not fail on convention.

## Deferred (measure-first, per evidence)

RAG link-following (1-hop neighbor-expansion of top-k memory/skill hits in retrieval.py) is
NOT built yet — requires an A/B hitgate eval first (Hit@5/MRR lift vs cosine+RRF baseline; e-series
experiment protocol per ADR-0045). Prior claim-vs-measurement splits (39% vs 66.7%) are exactly why.
Embedder upgrade (e6 bake-off rerun) outranks graph work.

Related: knowledge-brain.md, memory-vs-documentation.md, graphify-discipline.md, ADR-0045, ADR-0051.
