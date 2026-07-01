# Coverage & Drift Queries

Exact commands for Phase 2 (coverage) and Phase 3 (drift). Absorbed from the archived `adt-rag-coverage` and `adt-rag-drift` skills — kept as reference detail so `SKILL.md` stays lean.

## Coverage (Phase 2)

Weekly report gives the headline table:

```bash
cd ~/.claude/rag-index && venv/bin/python report.py
cat ~/.claude/rag-index/weekly.md | grep -A 50 "Coverage by source type"
```

Targets: skills ≥500, standards ≥50, handoffs ≥200 (scales with repo for code/plans/commits).

Drill into gaps directly against the index:

```bash
# By source type
sqlite3 ~/.claude/rag-index/index.sqlite "SELECT source_type, COUNT(*) FROM chunks GROUP BY source_type ORDER BY 2 DESC;"

# By repo (repos with <50 chunks likely have gaps)
sqlite3 ~/.claude/rag-index/index.sqlite "SELECT repo, COUNT(*), COUNT(DISTINCT path) FROM chunks WHERE repo IS NOT NULL GROUP BY repo ORDER BY 2 DESC;"

# Niche gaps (source type + repo combo under 20 chunks)
sqlite3 ~/.claude/rag-index/index.sqlite "SELECT source_type, repo, COUNT(*) FROM chunks WHERE repo IS NOT NULL GROUP BY source_type, repo HAVING COUNT(*) < 20 ORDER BY 1, 3 DESC;"
```

Zero-hit queries (`cat ~/.claude/rag-index/weekly.md | grep -A 20 "Zero-hit queries"`) point at missing topics — write/curate the doc, add source globs if it's code, incremental reindex, re-query to verify.

## Drift (Phase 3)

Stale-count thresholds (from the weekly report's drift summary):
- **<5 stale** — normal churn, can wait for next full rebuild
- **5–20 stale** — fix incrementally today
- **>20 stale** — full rebuild is faster than 20+ incremental ops

Delete orphaned chunks (file deleted since indexing):

```bash
sqlite3 ~/.claude/rag-index/index.sqlite "DELETE FROM chunks WHERE path = '<deleted-file-path>';"
```

Reindex modified chunks (file changed since indexing):

```bash
cd ~/.claude/rag-index && venv/bin/python build.py --incremental <changed-file-path>
```

Mark drift resolved (the `sessionstart-drift-reindex.sh` hook checks this to skip redundant corrections):

```bash
touch ~/.claude/rag-index/.last-drift-reindex
```

**Note:** `sessionstart-drift-reindex.sh` already runs an automatic pass at every session start and recommends a full rebuild past the >10-stale threshold. Phase 3 here is for manual/deeper intervention — the auto-detector missed something, or granular delete-vs-reindex-vs-rebuild control is needed.
