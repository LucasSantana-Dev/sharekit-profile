# Megabrain — one vault for all your projects

The `memory-structure` README covers a single project's memory. **Megabrain** scales it up to **one centralized vault that holds the memory, decisions, and knowledge graphs for *every* project you work on** — versioned in git, browsable in Obsidian, and retrievable by RAG. One brain, three consumers.

## The idea

Instead of per-repo memory that fragments, keep **one vault** (`$BRAIN_ROOT`) that is the single source of truth for cross-project knowledge. Three tools read the same markdown:

- **Obsidian** — visual graph + tag navigation (open `$BRAIN_ROOT` as a vault).
- **git** — versioned history, syncs across machines.
- **RAG / recall** — semantic retrieval over the notes (`recall` / a `search_knowledge` tool).

Each project's per-session memory is written under this one vault, so everything you learn anywhere lands in one searchable place.

## Layout

```
$BRAIN_ROOT/                 ← your megabrain
├── memory/
│   ├── MEMORY.md            ← curated Tier-1 index (≤ ~200 lines), auto-loaded each session
│   ├── CORE.md              ← Tier-0, always loaded
│   ├── *.md                 ← one note per fact, flat (no folders — tags navigate)
│   └── archive/             ← retired #meta/auto notes
├── graphs/
│   └── <project>/graph.json ← per-project knowledge-graph snapshots
└── .obsidian/               ← vault config (optional, for visual browsing)
```

## The one rule that matters most: edit in place

If you sync megabrain across machines (or consolidate from a session-capture tool) with an `rsync --update`-style copy (no `--delete`), then:

- **In-place edits stick** (newer mtime wins).
- **Moves / renames / deletes revert** — the source re-drops the old path, creating a duplicate.

**So do hygiene with frontmatter and tags, never file operations.** Don't rename a note — change a stable id in its frontmatter. Don't delete a stale note — tag it `status/superseded` or `status/archived`. The only safe "move" is a scripted archival that's reconciled to be authoritative before each commit.

## Frontmatter contract

```yaml
---
name: <unique-kebab-slug>
description: <one line — used for RAG retrieval AND the MEMORY.md index hook>
tags:
  - type/<kind>          # required
  - topic/<domain>       # optional
  - status/<lifecycle>
  - meta/auto            # machine-generated notes only
metadata:
  type: user | feedback | project | reference | decision
---
```

Required: `name`, `description`, a `tags` list, and a semantic `type`.

## Tag taxonomy — 4 axes, flat notes

Tags are the primary navigator (they replace folders, so notes stay flat and wikilinks never break):

| Axis | Meaning | Examples |
|------|---------|----------|
| `type/` | what kind of note | `decision` `project` `feedback` `reference` `adr` `audit` `session` |
| `topic/` | domain it's about | one tag per project or subject |
| `status/` | lifecycle | `active` (default) · `superseded` · `archived` · `draft` |
| `meta/` | provenance | `auto` (snapshots/sessions) · `untyped` (needs a type) |

## File naming

`<type-prefix>_<kebab-slug>[_<YYYY-MM-DD>].md` — e.g. `decision_caching_strategy_2026-01-12.md`, `feedback_review_style.md`, `adr_0007_event_bus.md`. Topic-named files are fine; the *type* then lives in the tag, not the name.

## Decisions / ADRs

Carry a **globally-unique id in frontmatter** (not the filename — filenames can collide if you never rename). Supersede an old decision by tagging it `status/superseded`, keeping the newest per topic `status/active`. Never delete history.

## Wikilinks

Link by note name/stem: `[[decision_caching_strategy_2026-01-12]]` — no prefix, no `.md`, no shorthand. Obsidian-native and agent-readable. Link liberally; a link to a not-yet-written note marks something worth capturing.

## MEMORY.md is intentionally small

A curated **Tier-1 index (≤ ~200 lines)** that auto-loads every session. Most notes are deliberately *not* in it — they're retrieved on demand via `recall`. Don't mass-add a pointer for every file, or the index stops being a signal.

## Retention

- Mark superseded decisions/backlogs `status/superseded` (keep the newest per topic `active`). Keep the old ones — they're history.
- Prune machine-generated `#meta/auto` snapshots/sessions on a schedule (e.g. keep the last N days inline, move older to `archive/`). Make `archive/` authoritative before each commit so the move survives a re-sync.

## Optional tooling to build

Megabrain works by hand, but small scripts make it durable:
- a **tagger** that backfills the 4-axis tags (idempotent),
- an **archiver** that enforces retention, reconciled to be authoritative pre-commit,
- a **committer** that syncs the vault across machines on a schedule,
- a **RAG indexer** (wired to `MEMORY_RETRIEVER`) over `memory/` for semantic `recall`.

## Evaluating retrieval — catch silent rot

Once megabrain has a retriever and hundreds of notes, recall degrades **silently**: a change makes the retriever surface worse notes and nothing warns you. Gate it (this is what the `memory-eval` skill does):

1. **Golden set** — `query → expected note(s)`, either hand-labeled (~30–50) or **label-free / auto-mined** from the notes themselves (no maintenance).
2. **Freeze a baseline** — `Hit@5 / Hit@1 / MRR` against the current retriever.
3. **Gate on regression** — re-run after any change to memories, retriever, chunking, or embedder; block/flag if a metric drops past tolerance.

This is the one thing no major agent-memory platform ships — *measurable* memory. **Honest caveat:** a label-free gate measures *retrievability change, not relevance* — it catches regressions, it doesn't prove recall is good. It's an advanced tier; the grep default needs none of it.

Start with just `memory/` + `MEMORY.md`. Add Obsidian, then graphs, then RAG, then the eval gate as megabrain grows — each is an independent upgrade.
