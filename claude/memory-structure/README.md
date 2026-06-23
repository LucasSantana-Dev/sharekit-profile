# Memory structure — a file-based knowledge system for AI agents

A convention for giving an AI coding agent a **persistent, file-based memory** that survives across sessions. This is the *structure and workflow* — adopt it and fill it with your own knowledge. (The skills that automate it assume a vault repo + optional RAG retriever; see Setup.)

## The idea

One directory of markdown files. Each file holds **one fact**. An index file lists them all. A tiny tier-0 file holds the always-loaded core. The agent reads the index each session, recalls relevant facts on demand, and writes new ones as it learns.

```
memory/
├── CORE.md          # tier-0: always loaded — identity, hard rules, priorities
├── MEMORY.md        # the index: one line per memory (loaded each session)
├── <fact-1>.md      # one fact per file
├── <fact-2>.md
└── ...
```

## One fact per file

Each memory file has frontmatter + a body:

```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary — used to decide relevance during recall>
metadata:
  type: user | feedback | project | reference
---

<the fact. For feedback/project, follow with **Why:** and **How to apply:** lines.
Link related memories with [[their-name]].>
```

**Types:**
- **user** — who the user is (role, expertise, preferences).
- **feedback** — guidance on how the agent should work (corrections + confirmed approaches). Include the *why*.
- **project** — ongoing work, goals, constraints not derivable from the code/git. Convert relative dates to absolute.
- **reference** — pointers to external resources (URLs, dashboards, tickets).

Link liberally with `[[name]]` (the other file's `name:` slug). A link to a not-yet-written memory is fine — it marks something worth capturing.

## The index (MEMORY.md)

One line per memory, newest knowledge wins:

```markdown
- [Title](fact-1.md) — short hook so the agent knows when it's relevant
- [Title](fact-2.md) — hook
```

`MEMORY.md` is loaded into context every session. Keep it to one line per memory — never put fact content here.

## Tier-0 (CORE.md)

The handful of things that are *always* true and must load every session: identity, hard preferences, top priorities. Everything else stays on-demand in the per-fact files.

## Capture & recall workflow

- **Capture** at session end, after a surprising gotcha, or when the user says "remember this." Before saving, check for an existing file that already covers it — update rather than duplicate. Delete memories that turn out wrong.
- **Recall** by scanning `MEMORY.md` descriptions; for a large vault, add a retrieval layer (see Setup) and query it *before* wide file reads.
- **Don't save** what the repo already records (code structure, git history, CLAUDE.md). If asked to remember something obvious, ask what was *non-obvious* about it and save that.
- Treat recalled memories as background context reflecting what was true *when written* — verify a named file/flag still exists before acting on it.

## Setup (to run the automation skills)

The included session/RAG skills expect:
- **`$BRAIN_ROOT`** — a git repo holding the `memory/` tree (so memory is versioned and syncable across machines). Set it in `~/.claude/settings.local.json` `env`.
- **Optional: a RAG retriever** — index `memory/` for semantic recall (any embedding-based search over the markdown). The `recall`/`adt-rag` skills call into one; without it they fall back to reading `MEMORY.md`.
- **Optional: a session-capture plugin** (e.g. claude-mem) for raw observation logging.

Start with just `CORE.md` + `MEMORY.md` + a few fact files — the retriever is an optimization, not a requirement.

See `examples/` for empty skeletons.
