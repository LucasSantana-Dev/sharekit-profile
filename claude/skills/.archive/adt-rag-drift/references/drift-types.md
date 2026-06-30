| Type | Cause | Effect | Fix |
|------|-------|--------|-----|
| **Missing** | File deleted (chunks remain indexed) | Retrieval returns orphaned chunks pointing to nonexistent files | Delete chunks from DB or full rebuild |
| **Modified** | File changed (chunks show old content, sha mismatch) | Queries return stale snippets; content differs from current source | Incremental reindex the modified files |
