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

## Works out of the box

The operational skills (`recall`, `sync-memories`, `knowledge-loop`, `memory-prune`) need **zero setup** — they default to a memory dir at `~/.claude/memory/` and use plain `grep` for retrieval. Install the profile, start writing facts with `sync-memories`, recall them with `recall`. No database, no embeddings, no mount.

Two optional upgrades, both via env vars in `~/.claude/settings.local.json` `env`:

- **`BRAIN_ROOT`** — point memory at a git repo instead of `~/.claude/memory/`, so it's versioned and syncs across machines. Everything still works; you just get history.
- **`MEMORY_RETRIEVER`** — a command template for semantic recall, e.g. `MEMORY_RETRIEVER="mytool query {} --top 5"` (the `{}` is replaced with the query). `recall` uses it when set and falls back to `grep` when unset. Wire it to any embedding search you like.

Start with just `CORE.md` + `MEMORY.md` + a few fact files. The git repo and the retriever are optimizations, not requirements. See `examples/` for empty skeletons; the RAG-pipeline guide in the `rag` skill covers building a retriever if you want one.

## Self-improvement protocol

The structure above is *knowledge persistence*. To make the harness **improve
with use** — observe → evaluate → optimize — see **[SELF_IMPROVEMENT.md](SELF_IMPROVEMENT.md)**.
It documents the **promotion ladder** (T0 scratch → T5 domain KB), **staleness
scoring** (`last_verified` / `change_frequency` / `confidence`), the
**PreCompact re-injection contract** (CORE memory survives compaction), and
the **nightly distill** (auto_dream stages candidates → host-agent graduate/
reject with required rationale). This is the closed loop that turns memory
into a flywheel; without it, saved notes are unmeasured and unvalidated.

## Scaling up: Megabrain

When you want *one* vault across **all** your projects — unified memory + decisions + knowledge graphs, browsable in Obsidian, versioned in git, retrievable by RAG — see **[MEGABRAIN.md](MEGABRAIN.md)**. It documents the full architecture: the 4-axis tag taxonomy (flat notes, tags-not-folders), the edit-in-place discipline for cross-machine sync, decision/ADR conventions, retention, and the optional tooling to build.
