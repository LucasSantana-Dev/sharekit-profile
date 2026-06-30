# Known-good external baselines

The harness has been validated on 7 corpora beyond the self-index. Use these as calibration
when setting expectations for a new corpus:

| Corpus | Language | n | Hit@5 | Hit@1 | MRR |
|---|---|---|---|---|---|
| FastAPI v0.115 | Python | 25 | 1.0 | 0.64 | 0.79 |
| forge-space/mcp-gateway | TypeScript | 20 | 1.0 | 0.70 | 0.821 |
| portfolio/src | React/TS | 15 | 1.0 | 0.60 | 0.778 |
| ai-dev-toolkit/packages/core | Python+TS | 20 | 1.0 | 0.85 | 0.925 |
| homelab/homelab\_manager | Python | 20 | 0.95 | 0.85 | 0.90 |
| Lucky/packages/backend | TypeScript | 21 | 0.905 | 0.71 | 0.810 |
| Criativaria/web-app | Next.js/TS | 27 | 0.741 | 0.59 | 0.660 |

**What the table predicts for a new corpus:**
- Functional module boundaries (service, adapter, config clearly separated) → Hit@5 ≥ 0.95
- Homogeneous UI component layer (sibling components share vocabulary) → Hit@5 ~0.74, consider reranker
- Hit@1 below 0.65 is normal and not a tuning failure — it reflects architectural ambiguity

Each baseline lives at `hitgate/baseline.<corpus>.json` in the evidence-first-rag repo.
Run `/rag-eval` with `RAG_EVAL_BASELINE=hitgate/baseline.<corpus>.json` to compare against any of them.
