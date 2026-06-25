---
name: context-pack
description: >-
  Assemble a task-aware context bundle before large changes, reviews, or entering unfamiliar
  code. Bootstrap fast by querying RAG first for decisions/patterns/why, then pull only the
  files/standards that matter. Use when refactoring multi-file systems, crossing repo
  boundaries, auditing unfamiliar work, or spending ≥5 reads exploring. Skip single-file
  edits and grep-answerable questions.
triggers:
  - context pack
  - gather relevant context
  - retrieve what matters
  - bootstrap me on this
  - load context for
  - pack my context
mcp_servers: [rag-index, serena]
---

# context-pack

Bootstrap task-aware context in <3 minutes.

## Workflow

**Step 1: Query RAG for decisions & patterns**
- **Check mount guard:** `mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted"; }` — if unmounted, surface blocker and fall back to step 2b.
- **Query RAG:** Use exact command pattern:
  ```bash
  python3 ~/.claude/rag-index/query.py "<task question>" --top 5 [--scope memory] [--fast]
  ```
  OR via MCP: `rag_query(query="<task question>", top=5, scope_types=["memory","handoffs","plans"])`
- **Done when:** top 5 results reviewed; ≥1 hit means context exists (cite line ranges, skip file reads).

**Step 2: Load active plans or handoffs**
- Check `~/.claude/handoffs/<project>/latest.md` and `.claude/plans/<task>*.md` for scope.
- Prefer these over wide file reads — they encode prior decisions.
- **Done when:** confirmed present/absent; if present, read and skip to output.

**Step 2b (if RAG blocked or empty): targeted file reads**
- Identify 2–3 smallest relevant files by name (not speculation).
- Read only the sections needed to act (cite line ranges).
- Do NOT speculatively expand the set.
- **Done when:** read set ≤3 files and each chunk ≤~20 lines.

**Step 3: Signal findings**
- Lead with verdict: "Context packed: X decisions found, Y files flagged, Z immediate blockers."
- List top 3 insights inline; bulk findings reference `references/full-context.md` ("ask for full list").
- Do NOT paste full-file contents or dump all RAG results.
- **Done when:** reader knows next action without additional context.

## Stop Conditions

- **RAG unavailable (External HD unmounted):** surface blocker clearly; do not hide it in fallback.
- **RAG returns ∅ AND no plans/handoffs exist:** read 2–3 files, stop. Expanding further dilutes signal.
- **Task touches one known file:** skip context-pack entirely; direct read is faster.
- **Marginal reads:** if the next read would not change the action, halt — each extra read dilutes budget.

## References

See `standards/workflow.md §3` (task-scoped retrieval discipline); `recall/SKILL.md` (verified RAG patterns).
For discovery strategy rules, see `references/discovery-strategy.md`.