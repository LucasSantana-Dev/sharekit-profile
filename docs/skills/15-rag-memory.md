# RAG & Memory Skills

Use `recall` for semantic lookup, `rag-maintenance` for index health, `knowledge-loop` for capture/curation/handoff, and `memory-prune` for stale memory cleanup. Archived narrow RAG commands are folded into `rag-maintenance`.

---

## /recall

One-shot semantic lookup against the local RAG index.

**Searches:** prior decisions, memory notes, handoffs, plans, skills, standards, docs, and indexed code.

**When to use:** Before broad file reads, when asking what was decided, or when prior reasoning may exist.

---

## /rag-maintenance

End-to-end RAG index maintenance: quality → coverage → drift → curation → rebuild decision.

**Integrated checks:**
- zero-hit and weak-hit queries
- cosine score interpretation
- stale/orphaned chunks
- source-type coverage
- memory filesystem vs indexed-memory coverage
- incremental reindex or full rebuild thresholds

**When to use:** Weekly maintenance, stale retrieval, low recall scores, bulk file/memory changes, or repeated recall misses.

---

## /knowledge-loop ⭐

Query, capture, improve, and persist knowledge in one workflow.

**Phases:**
1. Recall related prior reasoning.
2. Capture new decisions or state into memory.
3. Curate weak retrievals through `rag-maintenance` when needed.
4. Write handoff if session-ending or context-pressured.

**Rule:** create superseding memories for current state; do not rewrite historical memories as if old decisions never happened.

---

## /memory-prune

Audit project memory files for stale entries, merged PRs, closed issues, deleted files, and obsolete project state.

**When to use:** Memory index oversized, recall returns stale facts, or a project’s state changed materially.

---

## Knowledge-brain drift policy

If the filesystem has more memory files than the RAG index, record coverage drift and run `rag-maintenance` before relying on recall. If stale memories mention archived skill names, preserve them as history and add a current superseding memory.

**Last updated:** 2026-07-01
