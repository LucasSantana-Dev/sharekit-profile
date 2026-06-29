# Temporal knowledge graph — bi-temporal memory for the harness

This extends the existing promotion ladder (see [README.md](README.md) and
[SELF_IMPROVEMENT.md](SELF_IMPROVEMENT.md)) with a **bi-temporal** backbone. It
is *not* a second memory system: it layers temporal invariants onto the same
file-based vault so that history is never lost when a fact changes or stops
being true.

The Wave-5 memory/KG research track converged on three patterns that this doc
codifies:

1. **Supersede, never overwrite** — when a fact is corrected, write a new
   version and *link* the old one to it. The old fact stays (its body unchanged,
   its status flipped to `superseded`). (graphiti `add_episode` supersession;
   agmem versioned memory.)
2. **Bi-temporal validity windows** — every fact records *when it became true*
   (`valid_from`) and *when it stopped being true* (`valid_to`), as distinct from
   *when it was recorded* (`created_at`) and *last verified* (`last_verified`).
   A fact that is no longer true is not deleted; its `valid_to` is set. This
   preserves non-Markovian search: "what did we believe on date X?" stays
   answerable. (graphiti bi-temporal model.)
3. **Decay, never delete** — a fact that is stale (long unverified) and
   low-confidence is *archived* (`status: archived`), never removed. Forgetting
   is a visibility/retrieval concern, not a data-elimination concern.

## Why temporal

A plain file vault is append-mostly and overwrites-on-edit. That loses the
single most valuable property of a knowledge graph for a self-improving agent:
the ability to ask what was believed *when*, and to detect that a currently
held belief contradicts a previously superseded one. Bi-temporal recording
makes contradictions visible instead of invisible, and it lets the sleep cycle
(see below) recommend supersession *links* instead of silent overwrites.

## Fact frontmatter (temporal fields)

Extend the base frontmatter from [README.md](README.md) with these optional
temporal fields. Missing fields default; the harness degrades gracefully when
they are absent (see `memory-consolidate.sh`).

```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary>
metadata:
  type: user | feedback | project | reference
# Temporal (this doc):
valid_from: 2026-01-15          # when the fact BECAME true (may differ from created_at)
valid_to:                       # empty while currently true; set on supersession
created_at: 2026-01-15
last_verified: 2026-06-29       # last time an agent confirmed this still holds
confidence: 0.8                 # 0.0-1.0
change_frequency: 2             # how often this fact has been revised
status: active | superseded | archived
superseded_by: <newer-slug>     # set when status: superseded
tags: [context, governance]
---
```

- `valid_from` may predate `created_at` (we learned the fact later than it
  became true). Keep them distinct.
- `valid_to` is empty while the fact is currently true. Set it to the date it
  stopped being true when you supersede or archive it.
- `status: active` is the default. `superseded` means a newer fact replaces it
  (see `superseded_by`). `archived` means stale/low-confidence (decay), not
  replaced by anything specific.

## Supersession workflow

When a new fact contradicts or replaces an older one:

1. **Create the new fact file** with its own slug, `valid_from` set to today,
   `status: active`.
2. **Do not edit the old fact's body.** Instead, set on the old fact:
   `status: superseded`, `valid_to: <today>`, `superseded_by: <new-slug>`.
3. **Add a link** in the new fact's body: `Supersedes [[old-slug]] (as of
   <date>, because <reason>).`
4. **Keep both lines in MEMORY.md.** The index line for the old fact can note
   `(superseded <date>)` so recall surfaces recency without hiding history.

Graduating a supersession still goes through the review gate
(`hooks/review.sh graduate` with a rationale); the sleep cycle only *stages
candidates*, it never mutates semantic memory.

## Decay and forgetting

A fact is a **forget candidate** when it is both stale and low-confidence
(current heuristic in `memory-consolidate.sh`: `age > 90d` since
`last_verified` AND `confidence < 0.5`). Forgetting means:

- Set `status: archived` (and `valid_to` if not already set).
- Keep the file. Do not `rm`.
- Archived facts are excluded from the default recall set but remain searchable
  for non-Markovian queries ("what did we believe then?").

`change_frequency` accelerates decay signal: a fact revised many times that has
gone quiet is a stronger forget candidate than a stable one.

## Sleep-cycle consolidation

`hooks/memory-consolidate.sh` runs periodically (not per-turn) and performs a
**read-only** scan of `memory/`, staging a report to `.harness/forge/`:

- **Forget candidates** — stale + low-confidence facts to archive.
- **Supersede candidates** — facts sharing a title stem that may be versions of
  the same thing; recommend a supersession link, not an overwrite.
- **Compression clusters** — facts sharing tags that could compress into one
  higher-order note (promote toward T5 domain KB).

The report is never auto-applied. The host agent reviews it and graduates
items through `review.sh` with a required rationale, exactly like the nightly
distill (`distill.sh`). This keeps the closed loop
(observe -> evaluate -> optimize) honest: consolidation is a *proposal*, not a
mutation.

## Hybrid retrieval

Recall is hybrid, not pure semantic:

- **Recency** — `last_verified` and `valid_to` gate which facts are currently
  believed. Archived/superseded facts rank lower by default.
- **Relevance** — `MEMORY.md` descriptions (and the optional
  `MEMORY_RETRIEVER` from the base README) provide semantic recall.
- **Temporal query** — "what was believed on date X?" filters by
  `valid_from`/`valid_to` windows, surfacing superseded facts when the question
  is historical.

This hybrid (temporal + semantic + recency) is the retrieval analogue of the
hybrid context-control pattern (cache-prefix stability + tool-call-structure
preservation) used in the compaction guard. Both keep the agent anchored to
what was actually true at decision time, preventing drift.

## Invariants (enforced by convention + review gate)

- **Never overwrite a fact body.** Supersede via link + status flip.
- **Never delete a fact file.** Archive, do not `rm`.
- **Always record `valid_to` when a fact stops being true.** Erasing that it
  *was* true is a data-loss bug.
- **Consolidation is advisory.** `memory-consolidate.sh` stages; the host agent
  applies through the review gate with a rationale.
