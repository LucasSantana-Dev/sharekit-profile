# RAG & Memory Skills

`recall` for a quick semantic lookup before reading files. `adt-memory` to persist decisions across sessions. `memory-prune` when the memory index feels stale. `adt-rag-drift` when retrieval quality drops after files change.

---

## /recall

One-shot semantic lookup against the local RAG index — fuzzy, cross-file, or about prior reasoning.

**Searches:**
- Code files (by symbol, pattern, or concept)
- Prior decisions + ADRs
- Documentation + guides
- Configuration examples

**When to use:** Before reading files; quick knowledge lookup

**Output:** Relevant excerpts + context

---

## /adt-rag

Build and debug Retrieval-Augmented Generation pipelines — chunking, embedding, retrieval, reranking.

**Pipeline stages:**
1. **Chunking:** Split docs into retrievable units
2. **Embedding:** Convert chunks to vectors
3. **Storage:** Index vectors (FAISS, Pinecone, etc.)
4. **Retrieval:** Search by semantic similarity
5. **Reranking:** Score results, return top-K

**When to use:** Building custom RAG system

**Output:** RAG pipeline configuration + evaluation

---

## /adt-rag-context-pack

Build a task-aware context bundle via RAG, capped at a token budget.

**Process:**
1. Query RAG for relevant files/decisions
2. Fetch matching files up to token budget
3. Include project standards + ADRs
4. Return task-aware bundle

**When to use:** Before multi-file work; context-aware bundling

**Output:** Curated code + context + standards

---

## /adt-rag-coverage

Audit corpus distribution by source type and repo; identify coverage gaps and underindexed topics.

**Audits:**
- Source type distribution (code vs. docs vs. decisions)
- Repo distribution (which repos indexed?)
- Topic gaps (missing areas)
- Under-indexed files (long but low-retrieval)

**When to use:** Optimize retrieval index

**Output:** Coverage audit + gap identification

---

## /adt-rag-drift

Detect and fix stale chunks — files that changed or were deleted since last indexing.

**Detects:**
- Files changed but chunks not updated
- Deleted files still in index
- Line number mismatches
- Stale decision references

**When to use:** Retrieval quality dropped after refactoring

**Output:** Drift findings + cleanup steps

---

## /adt-rag-index-rebuild

Trigger a full or incremental reindex of the RAG corpus.

**Options:**
- **Full reindex:** Start from scratch (slow, comprehensive)
- **Incremental:** Add new files + update changed files (fast)

**When to use:** Updating RAG index; after drift cleanup

**Output:** Reindex complete + new corpus stats

---

## /adt-rag-inspect

Examine what's actually stored in the index for specific items.

**Inspects:**
- Which chunks exist for a file
- Embedding content (what was indexed?)
- Chunk boundaries (is chunking sensible?)
- Metadata (tags, source, etc.)

**When to use:** Debug retrieval quality; understand index

**Output:** Raw index contents + inspection report

---

## /adt-memory

Persist decisions, preferences, and project state across sessions using structured memory types.

**Memory types:**
- **User:** Role, preferences, behavior
- **Feedback:** How to approach work (rules + why)
- **Project:** Active work, deadlines, stakeholders
- **Reference:** External resource pointers

**When to use:** Capturing knowledge that future sessions need

**Output:** Saved memory file with frontmatter

---

## /sync-memories

Sync durable project or session knowledge into the available memory systems.

**Destinations:**
- Local memory (`~/.claude/memory/`)
- Persistent storage (`~/.claude-env/`)
- Vault index (for future recall)

**When to use:** After meaningful work; before context switch

**Output:** Synced memory + confirmation

---

## /memory-prune

Audit project memory files for stale entries — where cited PRs merged, bugs fixed, or files no longer exist.

**Identifies:**
- References to merged PRs (stale)
- References to closed issues (stale)
- References to deleted files (stale)
- Obsolete project state

**When to use:** Memory index oversized; prune decay

**Output:** Pruned memory files

---

## /knowledge-loop ⭐ **Composite**

Query, capture, improve, and persist knowledge: recall → sync-memories → rag-curate → handoff.

**Phases:**
1. **Recall:** Semantic search for related prior reasoning
2. **Sync:** Capture findings into memory types
3. **Curate:** Manually improve corpus quality
4. **Handoff:** Write resumable handoff

**When to use:** Capturing lessons learned; knowledge preservation

**Output:** Updated knowledge base + handoff

---

## /rag-curate

Manually improve corpus quality by adding missing docs and filling retrieval gaps.

**Operations:**
- Add missing documentation
- Rewrite unclear explanations
- Fix chunking boundaries
- Add cross-references

**When to use:** Improving retrieval quality after audit

**Output:** Improved RAG corpus

---

## /rag-quality

Evaluate retrieval quality from the local RAG index.

**Metrics:**
- Hit rate (% queries with relevant results)
- MRR (Mean Reciprocal Rank — relevance of top results)
- Per-intent coverage (which query types work?)
- False positive rate (% irrelevant results)

**When to use:** After RAG changes; quality check

**Output:** Retrieval quality report

---

**Last updated:** 2026-06-25
