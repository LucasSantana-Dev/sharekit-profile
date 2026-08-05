# The ML rigor behind sharekit's eval gate

sharekit reads, on the surface, as agent tooling: skills, hooks, an orchestration
substrate. The routing-eval gate (`evals/routing/README.md`) is the one place
that surfaces any ML discipline at all — a pinned baseline, human-verified
ground truth, a small-n statistical gate. Everything upstream of that gate is
invisible: it lives in ADRs and memory notes, never in the shipped product.

This doc makes that upstream work visible, and names the actual gap it
reveals: not a skill gap, an exposure gap.

## What the eval gate shows publicly

`evals/routing/README.md` documents 40 frozen tasks against an
OpenRouter-pinned model, gated on accuracy drop >5pp vs a fingerprinted
baseline. Small-n statistical gating, a fixed catalog, `--validate-only` for
offline CI. Solid, but it reads as a testing harness, not as ML work — nothing
in it says *why* 5pp, why frozen tasks over a live curriculum, or what
retrieval method sits underneath "routing" at all.

## What's underneath it: the E0-E6 program

None of this is visible from the eval gate, but it's why the gate is shaped
the way it is:

- **Embedding bake-offs** across e5, bge, and jina, including Matryoshka
  dimension-truncation trials — establishing which embedding model and which
  truncated dimension actually held up, not assumed.
- **A deliberately reproduced circularity-trap failure** — a known retrieval
  pathology (the ranker validating itself against its own outputs) reproduced
  on purpose to characterize it before guarding against it, not discovered by
  accident in production.
- **A distilled reranker vs. RRF ablation** on 7,850 teacher pairs — measured,
  not assumed, that cosine similarity is the actual bottleneck and that RRF is
  unbeatable at the ~100-label scale this system operates at.
- **LoRA fine-tuning** and **propensity/IPS counterfactual correction** —
  correcting for the selection bias in which labels get collected at all,
  not just fitting a model to the labels that exist.
- **A documented eval-protocol-drift incident** — the protocol itself broke
  at one point (measured, not assumed), and that failure is a first-class
  artifact, not a quietly-fixed bug.

Separately, a router-regex audit found the routing logic itself measured
broken, with a refresh in flight — the same "measure, don't assume" posture
applied to the harness's own routing, not just to retrieval.

None of this shows up in `evals/routing/README.md`. The gate's shape (small-n
gating, frozen tasks, a pinned baseline) is a direct consequence of this
program, but the program itself isn't cited.

## The same discipline, applied to a build-vs-adopt decision: Graphify

ADR-0036 (codebase-memory: MCP vs. Graphify hybrid) is the same rigor applied
somewhere with less flash: choosing whether to adopt a third-party
knowledge-graph tool. Graphify does tree-sitter parsing across 20+ languages,
Leiden community detection, and GraphRAG-style graph construction.

The evaluation wasn't a features comparison. A first pass got flagged
`NEEDS_REVISION` by a decision-critic for thin evidence and author bias — and
the response was to actually run a 3-query battery against a large monorepo
and report both tools' failures honestly, landing on a scoped hybrid rather
than a clean win for either side. That's a critic catching a real
methodology gap, and the author fixing the methodology instead of arguing
with the critic.

## The actual gap

The original worry was "we build AI tools but don't engage with the AI
technical depth: embeddings, supervised/unsupervised learning, RAG, vectors."
That's empirically false — the E0-E6 program and ADR-0036 are that depth,
done with real rigor (ablations, reproduced failure modes, critic-gated
revision, documented protocol drift).

The real gap is narrower and more fixable: **all of this is internal-only.**
It lives in `~/.claude/rag-index/experiments/` and ADRs that nothing
public-facing links to. `evals/routing/README.md` is downstream of a genuine
ML research program and doesn't say so. A reader (or a prospective enterprise
buyer evaluating the accountability story, per `docs/gtm/launch-plan.md`)
sees a testing harness and has no way to know it's backed by measured
ablations and a documented failure-mode catalog.

## What to do about it

Cite the program, don't rebuild it. Two smallest concrete moves:

1. Add a one-paragraph "methodology" section to `evals/routing/README.md`
   linking back to the E0-E6 findings that justify small-n gating and frozen
   tasks over a live curriculum.
2. Reference ADR-0036 from wherever the harness's memory/knowledge-graph
   design gets explained publicly (`docs/target-architecture.md` or
   equivalent), so the Graphify decision reads as a rigorous adoption
   evaluation instead of an unexplained dependency.

Both are documentation-only, no new research required — the substance
already exists, it just isn't linked from where a reader would find it.
