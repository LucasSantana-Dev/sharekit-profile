---
name: knowledge-loop
description: Pair recall + capture around a task — retrieve relevant memory first, persist new knowledge at the end. The closing loop that keeps file-based memory useful.
---

# Knowledge loop

Memory is only useful if you both **read** it and **write** it. This skill pairs the two so neither is forgotten.

## Phase 1 — Recall (always)

Run `recall` for the active task or question. Cite the hits, or state "no prior memory". If the user only asked a recall question, answer and stop — skip the rest.

**Done when:** relevant memory surfaced, or "no hits" stated.

## Phase 2 — Capture (if new durable knowledge was produced)

Run `sync-memories` with what was learned, decided, or built. Skip if the session was pure read/recall with no durable output.

**Done when:** the fact file(s) written and indexed in `MEMORY.md`.

## Phase 3 — Prune (occasional)

If recall surfaced near-duplicate or stale facts, run `memory-prune`.

## Reconciliation

Signal-first summary:

```
KNOWLEDGE LOOP — <topic>
  Recalled: <n> hits (or "none")
  Captured: <files written | skipped: reason>
  Pruned:   <n merged/deleted | skipped>
```

Each skip includes *why* (e.g. "skipped: pure recall session"), not just "skipped".
