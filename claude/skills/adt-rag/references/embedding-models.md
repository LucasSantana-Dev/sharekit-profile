# Embedding Models

## Common models

- `text-embedding-3-small` — OpenAI, compact, fast
- `text-embedding-ada-002` — OpenAI, legacy, well-studied
- `all-MiniLM-L6-v2` — open-source, local, low latency

## Critical rules

- Use the same model for indexing AND querying — mismatches break retrieval
- Normalize vectors before indexing (cosine similarity requires unit vectors)
- Re-embed when switching models — old vectors are incompatible
