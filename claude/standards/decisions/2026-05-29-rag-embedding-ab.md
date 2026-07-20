# RAG embedding model A/B — keep all-MiniLM-L6-v2

- Date: 2026-05-29
- Status: Accepted
- Pipeline: design-lock workflow (model-spec + adversarial critic + pre-registered decision rule) → isolated A/B on real corpus → this ADR

## Context

Tested whether a modern OSS embedding model beats the prod `all-MiniLM-L6-v2` (384-dim) on the live RAG: 8,372 chunks, 211-case eval, hybrid BM25+dense+RRF(+optional rerank). Fully isolated (prod `index.sqlite` untouched; per-model DBs on external drive). Methodology was adversarially pre-critiqued (DIM auto-detect, per-model query/doc prefixes, cache-collision avoided via per-model processes, McNemar + bootstrap CI, per-category, rerank-off/on cells, pre-registered ADOPT gate).

## Decision

**Keep `all-MiniLM-L6-v2`. No embedding change.**

- **REJECT `nomic-v1.5`** (768-dim): ΔMRR +0.026 (rerank-off) is within noise — McNemar **p=1.000** (5 wins / 4 losses on Hit@5), MRR-Δ 95% CI **[−0.003, +0.055] crosses zero**, ΔHit@5 +0.005 (flat). With rerank ON it is marginally *worse* than minilm. Cost: 2.0× index, 0.54 GB model, 9 min re-embed. Fails the pre-registered gate (needed ΔMRR≥+0.04 ∧ ΔHit@5≥+0.05 ∧ p<0.05 ∧ idx<1.5×).
- **REJECT `bge-m3` + `qwen3-0.6b`** (560–600M params): hardware-infeasible on the 24 GB Mac — measured ~600 s/batch under swap-thrash (~43 h projected), fails the embed<15 min gate by >150×.

## Key finding (higher-ROI than any embedding swap)

The **cross-encoder reranker is the real lever**, and it's already installed but `RAG_RERANK=off` by default. Enabling it lifts **minilm** MRR +0.038 / Hit@5 +0.029 — larger than the nomic embedding swap, with **no re-embed and no index bloat**.

Caveat: rerank adds ~150 ms/query + a cross-encoder cold-load per process. Good for interactive `recall`/`context-pack`; **not** for the per-prompt `autorecall` hook (fresh process per prompt → ~1–2 s model-load tax every turn). So enable selectively, not globally. A heavier reranker (`bge-reranker-v2-m3`, 568M) is itself hardware-infeasible here — stick with the lightweight `ms-marco-MiniLM`.

## Alternatives considered

- nomic-v1.5 swap — rejected (noise, 2× index).
- bge-m3 / qwen3 swap — rejected (hardware).
- Do nothing — confirmed: hybrid + minilm is near-optimal for this corpus; the embedding is not the bottleneck (validates the 2026-05-28 RAG-quality DEFER).

## Consequences

- (+) Stop spending on embedding upgrades; the question is settled with corpus-specific evidence, not generic MTEB.
- (+) Surfaced a free, larger lever (selective rerank enablement) as the next candidate.
- (~) The 24 GB RAM ceiling is the dominant constraint for any heavy local model — relevant to future RAG/model work.

## Revisit when

- The reranker-enablement decision is taken up (its own call: latency vs per-prompt cold-load; needs a warm-pool or path-scoped flag).
- Hardware changes (more RAM) or `agent-box` is wired for embedding jobs → bge-m3/qwen3 become testable.
- A query-log-driven feedback loop (`queries.sqlite` → grow eval set → re-tune) is built — the actual "auto-improve" mechanism, a separate decision.
