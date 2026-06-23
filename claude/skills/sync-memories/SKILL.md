---
name: sync-memories
description: Capture durable knowledge to file-based memory — one fact per file plus an index update. Zero-dependency; commits if memory is a git repo.
---

# Sync memories (capture)

Persist what was learned or decided this session so a future session can `recall` it.

## When

- Session end, a decision reached, or a surprising gotcha worth not re-learning.
- The user says "remember this".
- **Skip** if the session was pure read/recall with no durable output.

## Where memory lives

```
${BRAIN_ROOT:-$HOME/.claude/memory}
```

## How

1. **Decide the fact.** One fact per file:
   - `name` — short kebab-case slug.
   - `description` — one line (this is what `recall` matches on, so make it specific).
   - `type` — `user` (who the user is) · `feedback` (how to work, with the *why*) · `project` (ongoing work/constraints; use absolute dates) · `reference` (external pointer).
2. **Check for an existing file** that already covers it — update that file rather than duplicate. Delete memories that turn out wrong.
3. **Write the fact** to `$MEM/<slug>.md`:
   ```markdown
   ---
   name: <slug>
   description: <one-line>
   metadata:
     type: <type>
   ---
   <the fact, stated plainly. For feedback/project, add **Why:** and **How to apply:** lines.
   Link related memories with [[other-slug]].>
   ```
4. **Append to the index** `$MEM/MEMORY.md`:
   ```
   - [<Title>](<slug>.md) — <short hook>
   ```
5. **Version it** if memory is a git repo: `git -C "$MEM" add -A && git -C "$MEM" commit -m "memory: <slug>"`.

## Don't save

What the repo already records (code structure, past fixes, git history, project config) or what only matters to this one conversation. If asked to remember one of those, ask what was *non-obvious* about it and save that instead.
