# Coverage Decision Tree

Quick reference for diagnosis and response.

| Situation | Detection | Action | Time |
|-----------|-----------|--------|------|
| Source type <50% of target | Weekly report | Write missing docs + curate | 30 min – 2 hrs |
| Repo has <50 chunks | rag-coverage query | Add source globs to build.py + reindex | 20 min |
| Zero-hit queries | Weekly report or user feedback | Identify missing topic, curate, reindex | 30 min |
| Many tiny chunks (<100 chars) | adt-rag-inspect | Rebuild with new chunk-size config | 1 hr |
| Stale/missing chunks | adt-rag-drift | Delete or reindex; see adt-rag-drift | 10 min |
| Widespread gaps (>100 chunks missing) | Weekly report | Full rebuild | 2–5 min |
