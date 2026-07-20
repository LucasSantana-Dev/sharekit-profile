# Memory vs Project Documentation — knowledge taxonomy

**Status:** active (defined 2026-06-25). Canonical answer to "is this a memory or project documentation?"

Every durable fact lands in exactly **one** of three classes. The decisive axis is
**portability + ownership**, building on the CLAUDE.md hard rule "repository as single source of
truth for agent-actionable context."

## The three classes

### 1. Memory — *how we work + what we learned* (portable, person/agent-scoped)
- **Is:** decisions-as-principles, gotchas, feedback/preferences, cross-project patterns,
  "we tried X, it failed/worked," session learnings worth keeping.
- **Test:** *"Is it about **us / how we work**, and **portable** across projects?"* → Memory.
- **Lives in:** the `knowledge-brain/` vault `memory/` (+ `~/.codex/memories`, `~/.serena/memories`).
- **Indexed as:** `source_type=memory`. Retrieved via `recall` / autorecall / `search_knowledge`.
- **Lifecycle:** curated, prunable, can go stale → archive. The `MEMORY.md` index is the map (≤200 lines).

### 2. Project documentation — *canonical facts to act on THIS project* (repo-scoped)
- **Is:** ADRs, specs, architecture / `CONTEXT.md`, README, standards-for-that-repo, schema,
  API docs, roadmap, changelog.
- **Test (CLAUDE.md):** *"Would a future agent need this **committed in the repo** to make a
  correct decision **about this project**?"* → Project documentation → **lives IN the project repo.**
- **Lives in:** the project repository (`docs/`, `docs/adr/`, `README.md`). **Not** the personal vault.
- **Indexed as:** `source_type=adrs|spec|standards|repo-docs|repo-readme|roadmap|changelog`,
  scoped to the repo.
- **Lifecycle:** versioned with the code; the source of truth. Must be committed *before* an agent
  acts on it.

### 3. Ephemeral / operational — *time-bound record of an event* (not durable knowledge)
- **Is:** handoffs (resume packets), commit messages, session snapshots, raw logs.
- **Test:** *"Is it a record of **a session/event**, not a reusable fact?"* → Ephemeral.
- **Lives in:** `~/.claude/handoffs/`, git history.
- **Indexed as:** **card-only** — one ~24-token CARD (title + first line), NOT full chunks
  (`build.py` `CARD_ONLY_TYPES`, default `handoffs`). Still findable; ~10–20× lighter.
- **Lifecycle:** transient; superseded by the next one. Never the source of truth.

## The boundary you'll actually hit: Memory vs Project-doc

> **Project-specific fact → that repo's docs/ADR.  Portable learning/preference/gotcha → memory.**

- "rag-index's eval gate = memory-target Hit@5 ≥ 0.75" → **project doc** (ADR in rag-index). ✓ ADR-0037.
- "bulk-mining eval cases creates noise; prefer curated golden sets" → **memory / standard** (portable principle).
- "Handoff: here's where I left the RAG refactor" → **ephemeral** (card-only).

When unsure, ask: *does the fact stop being true / relevant if you change projects?* If yes → project
doc. If it's a lesson you'd carry to any project → memory.

## Why this matters for retrieval cost

The index was ~40% ephemeral (handoffs @ ~523 tok/chunk). Classifying correctly + card-only
ephemeral indexing (C1) cut handoff index tokens ~97% with no loss of findability, and
`query.py --snippet` (C2, default 400 chars; `--full` to override) keeps every hit token-thrifty.
Cleaner classes → tighter scoping → fewer, more relevant hits → cheaper search.

## Operational rules
- A fact that's agent-actionable for a project **must be committed to that repo** before acting on it
  (don't leave it only in memory/Slack).
- Don't duplicate a project doc into memory (one home per fact); a memory note may *point* to a repo doc.
- Ephemeral records are card-only in the index — to add a new ephemeral type, append it to
  `RAG_CARD_ONLY` in `build.py`.
