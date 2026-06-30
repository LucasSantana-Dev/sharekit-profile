---
name: rag-drift
description: Detect and fix stale chunks (files that changed or were deleted since last indexing)
triggers:
  - rag drift
  - stale chunks
  - rag outdated
  - drift detection
---

# RAG Drift

**Drift** occurs when the index contains chunks from files that have been deleted or modified since indexing. The retrieval system silently returns outdated or orphaned content without error. Detect and fix drift before it degrades quality.

## What is drift?

Two types of drift corrupt the index: see `references/drift-types.md` for details.

Drift is **silent.** Retrieval still works, but returns wrong or outdated info.

## Detect drift

**BLOCKED if External HD unmounted** — report.py embedder cache unreachable; query local sqlite instead.

**Check stale count:** Read the drift summary to determine action:
- <5 stale chunks: normal churn; can wait for next full rebuild
- 5–20 chunks: fix incrementally today
- >20 chunks: full rebuild recommended (faster than 20+ incremental ops)

Run the report script:

```bash
cd ~/.claude/rag-index
venv/bin/python report.py
```

Read the drift summary:

```bash
cat ~/.claude/rag-index/weekly.md | grep -A 30 "Stale chunks"
```

See `references/report-examples.md` for example output.

**Done when:** report shows stale count and recommended action based on thresholds above.

## Fix missing chunks (deleted files)

For files that no longer exist, delete their orphaned chunks:

```bash
sqlite3 ~/.claude/rag-index/index.sqlite
```

In the sqlite prompt:

```sql
-- View chunks from the deleted file
SELECT COUNT(*), path FROM chunks 
WHERE path LIKE '%old-skill/SKILL.md%'
GROUP BY path;

-- Delete them
DELETE FROM chunks 
WHERE path LIKE '%old-skill/SKILL.md%';

-- Confirm deletion
SELECT COUNT(*) FROM chunks 
WHERE path LIKE '%old-skill/SKILL.md%';
```

Exit sqlite: `.exit`

**Quick delete (one line):**

```bash
sqlite3 ~/.claude/rag-index/index.sqlite \
  "DELETE FROM chunks WHERE path = '~/.claude/old-skill/SKILL.md';"
```

**Done when:** sqlite confirms 0 chunks for that path (query returns no rows).

## Fix modified chunks (updated files)

Files that exist but have changed since indexing need incremental reindex:

```bash
cd ~/.claude/rag-index
venv/bin/python build.py --incremental ~/.claude/standards/old-auth.md
```

The incremental reindex will:
1. Delete old chunks from that file
2. Re-embed and insert new chunks with current content
3. Leave all other chunks untouched

**Done when:** re-run report shows stale count returned to baseline or <5.

## Auto-drift detection

The sessionstart hook (`sessionstart-drift-reindex.sh`) runs at session start:
- Checks for >10 stale chunks
- Recommends full rebuild if drift is significant
- Logs to `~/.claude/rag-index/drift.log`

This skill is for **manual drift intervention.** Use when:
- The auto-detector misses something
- You want granular control (delete vs. reindex vs. rebuild)
- Troubleshooting index corruption

## Prevent drift

- Run `report.py` weekly to catch drift early
- After bulk file deletions, run a full rebuild
- After significant content updates, incremental reindex those files
- Archive old docs instead of deleting; move to `~/.claude/archive/` instead of `rm`

## The `.last-drift-reindex` marker

After fixing drift, optionally update the marker file:

```bash
touch ~/.claude/rag-index/.last-drift-reindex
```

This marks the time drift was last resolved. The sessionstart hook checks this to avoid redundant corrections.

## Troubleshooting

**"Stale chunks count is high but report looks clean"**
- Run `report.py` again to refresh: `venv/bin/python report.py`
- Check the report timestamp: `stat ~/.claude/rag-index/weekly.md`

**"Incremental reindex didn't fix drift"**
- Verify the file path is correct and the file exists
- Run `report.py` again to see if stale count changed
- If still high, use full rebuild

**"Full rebuild but chunks didn't decrease"**
- Check if new files were added at the same time
- Query count may be stable if source repos are unchanged
- Run `inspect` skill to audit what's in the index

## See also

- `adt-rag-index-rebuild` — full or incremental reindex after drift
- `adt-rag-quality` — check retrieval quality; zero-hits may indicate drift
- `adt-rag-inspect` — examine chunks in the database
