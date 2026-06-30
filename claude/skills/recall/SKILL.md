---
name: recall
description: One-shot semantic lookup against the local RAG index — answers "what did we decide about X", "where did we hit this bug before", "is there a memory note for Y" in a single MCP call. Backed by the `rag_query` MCP tool over ~21k chunks (memory, plans, handoffs, skills, standards, docs, code, commits) across curated repos. Auto-scopes to current repo. Use instead of grep when the question is fuzzy, cross-file, or about prior reasoning. Skip for pure navigation or single-file edits.
triggers:
  - recall
  - have we seen this before
  - did we decide
  - prior context on
  - what did we learn about
  - is there a memory note for
---

# recall

Single-shot RAG lookup. Don't over-fetch.

**Mount guard:** `mount | grep -q /Volumes/External\ HD || echo WARNING: RAG degraded` — the index lives on the External HD; an unmounted drive silently degrades recall. See `standards/knowledge-brain.md §1`.

## How

Call the MCP tool directly:

```
rag_query(query="<natural-language question>", top=5)
```

**Done when:** top results answer your question in 1–2 chunks. If not, narrow the query or increase `top` (up to 8).

Optional args:
- `top` (1–20, default 5) — more isn't always better; reranker quality drops past 8.
- `scope_types` — narrow to e.g. `["memory", "handoffs"]` for "what did I write down" queries, or `["commit"]` for "what did we ship lately on X".
- `scope_repos` — pass `["all"]` to ignore cwd auto-scope; pass `["Lucky"]` etc. to force a specific repo.

## Failure modes

- **Unmounted External HD** — if the drive drops mid-session, the RAG index becomes stale or inaccessible. Mount guard (above) catches this; surface "WARNING: RAG degraded" and skip the query or fall back to grep.
- **Stale index** — if memory or code changed recently and the reindex hook hasn't run (2–5 minute lag typical), you may miss the latest decisions or commits. Fallback: ask directly ("what did we just decide") or grep recent files / `git log`.
- **Low-quality rerank** — if you ask a vague question ("fix this") without context, the reranker may return false positives. Be specific ("why did we choose D1 for Progress Tracker storage").

## Anatomy of results

A `rag_query()` result includes:

```json
{
  "results": [
    {
      "text": "<chunk content>",
      "source": {
        "type": "memory" | "handoff" | "plan" | "commit" | "code" | "readme",
        "repo": "Lucky" | "homelab" | "...",
        "path": "..."
      },
      "score": 0.87  // reranker confidence; >0.8 usually relevant
    }
  ]
}
```

Typical scores: relevant = 0.75+; weak relevance = 0.50–0.75; noise = <0.50. Higher `top` → more noise. See `standards/skill-patterns.md §completion-criteria` for "Done when" discipline.

## When recall beats grep

- "Why is this written this way" — answers live in memory/plans/commits, not the file.
- Cross-repo questions ("is this pattern used elsewhere") — index covers 5 repos.
- Past-incident lookup — `feedback_*.md` memory files surface here, not in repo grep.
- Onboarding into an unfamiliar area — gets 5 best chunks across all source types in one call.

## When grep / serena beats recall

- "Where is `function X` defined" — `mcp__serena__find_symbol` or `grep` is faster + exact.
- Single-file scoped edits — open the file.
- Recent state ("did this change today") — `git log` / `git diff` is authoritative; the index lags by minutes-to-hours depending on whether the post-edit reindex hook ran.

## Pair with

- `context-pack` when one query isn't enough and you need a multi-source bundle.
- `dispatch` when the question fans into multiple parallel investigations.
