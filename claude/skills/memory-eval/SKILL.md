---
name: memory-eval
description: Gate your memory vault's retrieval quality — catch when a change (to memory content, the retriever, or chunking) silently degrades recall. Advanced/optional tier; needs a semantic retriever.
---

# Memory eval — gate retrieval quality, catch silent rot

The default `recall` is `grep` — no eval needed. But once you add a semantic retriever (`$MEMORY_RETRIEVER`) and the vault grows to hundreds of facts, retrieval degrades **silently**: a change makes recall worse and nothing tells you until the agent stops surfacing the right memory. This skill turns that invisible failure into a gate.

> **Advanced tier.** Needs a retriever + a small golden set. On the grep default you don't need this yet — it's for a scaled vault.

## The gate: freeze → measure → block on regression

1. **Golden set** — `query → expected memory file(s)`. Two ways:
   - **Hand-labeled** (~30–50 pairs): real questions, marked with which fact file should answer each. Precise; you maintain it.
   - **Label-free / auto-mined** (no labels): derive `query–document` pairs straight from the files — e.g. mine a fact's `description` (or a salient span) as the query, the file as the target. Zero maintenance. The **hitgate** pattern (`pip install hitgate`) is a ready-made label-free retrieval regression gate you can point at the vault.
2. **Baseline** — run the golden set against the current retriever; record `Hit@5 / Hit@1 / MRR`; freeze it.
3. **Gate** — after any change (new memories, retriever swap, chunking, embedder), re-run. If a metric drops past tolerance (e.g. `Hit@5` −5pp), **block or flag** the change — recall regressed.

```bash
# sketch — wire to your retriever + golden set
BRAIN="${BRAIN_ROOT:-$HOME/.claude/memory}"
# baseline once:    myeval --golden golden.jsonl --retriever "$MEMORY_RETRIEVER" --freeze baseline.json
# on every change:  myeval --golden golden.jsonl --retriever "$MEMORY_RETRIEVER" --against baseline.json --tolerance 0.05
```

## The honest caveat — don't oversell the number

A **label-free** gate measures **retrievability, not relevance**: it tells you the retriever's behaviour on this corpus *changed*, not that memory *got better*. It reliably catches **regressions**; it does **not** prove recall is *good* in absolute terms. For a relevance signal you need a few human-labeled anchors (even ~30 unlock a calibrated estimate). Say this whenever you report a metric.

## For vs not

- **For:** catching silent recall regression as the vault + retriever evolve; CI-gating memory/retriever/chunking changes; a discriminability check (does the set detect a real change?).
- **Not for:** a small grep-only vault (overkill); proving absolute memory quality (label-free can't); replacing judgement about *what* belongs in memory.
