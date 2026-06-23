---
name: recall
description: Retrieve relevant past knowledge from file-based memory before acting. Grep-based by default (zero-dependency); uses a configured semantic retriever if one is available.
---

# Recall

Pull relevant facts from memory **before** wide exploration, or whenever the user asks "what did we decide about X / is there a note on Y / where did we leave Z".

## Where memory lives

```
${BRAIN_ROOT:-$HOME/.claude/memory}
```

A directory of markdown facts with a `MEMORY.md` index and a `CORE.md` tier-0. See `memory-structure/` for the convention. Works out of the box — no database, no embeddings required.

## How to recall (cheapest first)

1. **Index scan.** Read `MEMORY.md` — its one-line descriptions usually tell you which facts are relevant. Often this is enough.
2. **Keyword grep** (the zero-dependency default):
   ```bash
   MEM="${BRAIN_ROOT:-$HOME/.claude/memory}"
   grep -rilE "<keyword1|keyword2>" "$MEM" --include='*.md'
   ```
   Read the matching fact files in full.
3. **Semantic retriever (optional).** If `$MEMORY_RETRIEVER` is set — a command template that takes a query and prints matching file paths — use it for fuzzy/semantic recall:
   ```bash
   if [ -n "$MEMORY_RETRIEVER" ]; then eval "${MEMORY_RETRIEVER/\{\}/<query>}"; else echo "(no retriever — using grep)"; fi
   ```
   Unset → step 2 is the fallback. (Wire `$MEMORY_RETRIEVER` to any embedding search, e.g. `mytool query {} --top 5`.)

## When to recall

- Before wide Grep/Read sweeps on a question memory might already answer.
- On "what did we decide / is there a memory for / where did we leave X".
- At the start of any non-trivial task.

## Output

Cite the fact file(s) and give the answer. Treat a recalled fact as reflecting what was true *when written* — verify a named file/flag still exists before acting on it. If nothing matches, say so plainly; don't fabricate.
