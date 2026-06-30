# Score Interpretation Scale

## Cosine Similarity Meaning (0.0–1.0)

| Cosine | Meaning | Action |
|--------|---------|--------|
| <0.25 | No meaningful match — corpus has a gap | Add docs, then curate |
| 0.25–0.40 | Weak hit — system retrieved *something*, but poorly | Curate corpus or rephrase query |
| 0.40–0.55 | Borderline hit — may or may not be useful | Monitor; curate if repeated |
| >0.55 | Good hit — relevant and confident | Working as intended |

**Zero-hit threshold:** If cosine is below 0.25 for all results, the corpus does not contain knowledge for that query.

## Score Components

From the query output:

- **`rrf`** = reciprocal rank fusion (combined BM25 + cosine; higher is better)
- **`cos`** = cosine similarity (0–1; the primary quality metric)
- **`bm25`** = keyword match strength (context-dependent)
