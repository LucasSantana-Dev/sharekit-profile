# Memory vs Project Documentation

Every durable fact lands in exactly one of three classes. The decisive axis is portability and ownership; the repository is the single source of truth for agent-actionable context.

## The three classes

### 1. Memory: how we work and what we learned (portable, person/agent-scoped)
- Is: decisions-as-principles, gotchas, feedback/preferences, cross-project patterns, "we tried X, it failed/worked", session learnings worth keeping.
- Test: is it about us / how we work, and portable across projects? Then memory.
- Lives in: the `knowledge-brain/` vault `memory/` (plus `~/.codex/memories`, `~/.serena/memories`). Indexed as `source_type=memory`; retrieved via `recall`, autorecall, `search_knowledge`.
- Lifecycle: curated, prunable, archived when stale. The `MEMORY.md` index is the map (max 200 lines).

### 2. Project documentation: canonical facts to act on THIS project (repo-scoped)
- Is: the repo decision log (`DECISIONS.md`), gated full ADRs (`docs/adr/`), specs, architecture / `CONTEXT.md`, README, repo standards, schema, API docs, roadmap, changelog, runbooks.
- Test: would a future agent need this committed in the repo to make a correct decision about this project? Then it lives in the project repo (`docs/`, `docs/adr/`, `README.md`), not the personal vault.
- Indexed as `source_type=adrs|spec|standards|repo-docs|repo-readme|roadmap|changelog`, scoped to the repo.
- Lifecycle: versioned with the code; commit it before an agent acts on it.

### 3. Ephemeral / operational: time-bound record of an event
- Is: handoffs (resume packets), commit messages, session snapshots, raw logs.
- Test: is it a record of a session/event, not a reusable fact? Then ephemeral.
- Lives in `~/.claude/handoffs/` and git history. Indexed card-only (one short CARD of title plus first line, not full chunks; `build.py` `CARD_ONLY_TYPES`, default `handoffs`). Transient, superseded by the next one, never the source of truth.

## Boundary: memory vs project doc

Project-specific fact goes to that repo's docs/ADR. Portable learning, preference or gotcha goes to memory. When unsure: does the fact stop being true or relevant if you change projects? If yes, project doc. If it is a lesson you would carry to any project, memory.

Examples: "rag-index eval gate = memory-target Hit@5 >= 0.75" is a project doc (ADR in rag-index). "Bulk-mining eval cases creates noise; prefer curated golden sets" is memory/standard. "Where I left the RAG refactor" is ephemeral.

## Operational rules
- A fact that is agent-actionable for a project must be committed to that repo before acting on it; never leave it only in memory or chat.
- Do not duplicate a project doc into memory (one home per fact); a memory note may point to a repo doc.
- Decisions default to one status-prefixed line in the repo's `DECISIONS.md`; full ADRs only behind the record gate (public-facing repo, sprint-level undo cost, recurring-alternative rejection, post-incident). See `adr-write`.
- To add a new ephemeral type to card-only indexing, append it to `RAG_CARD_ONLY` in `build.py`.

## Documentation hygiene
- Keep durable docs in durable places. Root-level docs are stable project docs, not task residue.
- Put session-specific plans and notes under `.claude/plans/`, `.claude/tasks/`, or `.claude/handoffs/`.
- Update README, changelog, or runbooks when user-visible behavior or operator workflow changes.

## Linking conventions (memories, ADRs, knowledge-brain docs)

Link selectively: more meaningful connections, not more connections. Exhaustive linking adds index bloat and noise; links serve navigation and staleness tracing, not ranking. Write for signal, not count.

1. Every new memory/knowledge doc has at least 1 and at most about 5 real links. Before writing, scan the project's `MEMORY.md` index for neighbors and link the load-bearing ones as `[[name]]` (the target's frontmatter `name:` slug). A link to a not-yet-written note is allowed (marks a gap) but must be plausible, not decorative. Zero links is an orphan (validator warns); more than about 5 is noise.
2. Name entities explicitly in prose: ADR numbers (`ADR-0051`), skill names, file paths, repo names, incident dates. Shared entities are implicit retrieval edges.
3. Bidirectional links only when load-bearing. If a new note supersedes, resolves or refines an existing one, update the OLD note's status line to point forward. Do not backfill reciprocal links for mere mentions.
4. Enrich, do not orphan: prefer updating an existing connected note over a near-duplicate. New note only for a genuinely new fact.
5. ADRs use typed relation header lines naming prior ADRs: `Supersedes:`, `Builds on:`, `Refines:`. Memories citing decisions name the ADR number.
6. Machine-greppable staleness: any follow-up or expiry gets an explicit line `re-check: YYYY-MM-DD, <what to verify>`. Resolved items flip to `RESOLVED YYYY-MM-DD` in the description. Prose like "check back mid July" is invisible to audits.
7. Each project's `MEMORY.md` is its hub: every memory gets one indexed line with 1-2 `[[links]]` in the hook text. No separate MOC files.

Validator: `~/.claude/scripts/memory-link-check.sh <memory-dir>` is a read-only reporter of orphans (zero `[[links]]`), dangling `[[targets]]` (no matching `name:` slug in the dir) and passed `re-check:` dates. Run via `/memory-prune`, `/sync-memories` close-out, or ad hoc. It warns, never blocks; memory capture must not fail on convention.

RAG link-following (1-hop neighbor expansion of top-k hits) is not built; it requires an A/B hitgate eval first (Hit@5/MRR lift vs the cosine+RRF baseline, per ADR-0045).

Related: knowledge-brain.md, ADR-0045, ADR-0051.
