# Discovery Strategy

Rules for task-scoped context retrieval.

## Preferred sources (in order)

1. **RAG query** — hybrid BM25 + cosine over local index (memory, plans, handoffs, commits, code). Auto-scopes to current repo; pass `scope_repos: ["all"]` to disable.
2. **Active plans / handoffs** — `~/.claude/handoffs/<project>/latest.md`, `.claude/plans/`.
3. **Standards** — cite `~/.claude/standards/<file>.md §N` only when relevant (do not load all).
4. **Targeted file reads** — smallest relevant files; cite line ranges; ≤20 lines per chunk.

## Symbol lookup strategy

- **"Where is X defined?"** — use `mcp__serena__find_symbol` or grep before RAG (faster for exact matches).
- **"Why is X written this way?"** — RAG wins (decisions, rationale, patterns).
- **"What files reference Y?"** — use `mcp__serena__find_referencing_symbols`.

## Chunking discipline

- Surface only what's needed to act.
- Name the file and cite line ranges.
- Paste at most ~20 lines per chunk.
- Do NOT dump entire files.

## Anti-patterns

- Speculatively expanding read set beyond 2–3 files.
- Loading all standards when only task-relevant ones matter.
- Pasting multi-page files instead of ranges.
- Querying RAG *after* skimming 10 files (RAG-first wins).
