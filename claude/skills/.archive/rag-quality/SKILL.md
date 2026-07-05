---
name: rag-quality
description: Evaluate retrieval quality from the local RAG index
triggers:
  - rag quality
  - retrieval quality
  - query scores
  - rag performance
---

# RAG Quality

Measure how well the RAG system retrieves relevant documents. Identify zero-hit queries (gaps in the corpus), low-confidence hits, and retrieval quality regressions.

## Stop if

**Stop if:** External HD is unmounted → RAG index is unreachable and results will be empty/stale.

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG index unreachable"; exit 1; }
```

Without the mount, do not proceed. Fall back to grep-based search instead.

## Quick quality check

Start with the weekly report:

```bash
cat ~/.claude/rag-index/weekly.md
```

This shows:
- Zero-hit query list (queries with no results above cosine 0.25)
- Stale chunk count (outdated or orphaned chunks)
- Chunk distribution by source type and repo
- Quality summary table

**The report is authoritative.** If it's >1 week old, refresh it:

```bash
cd ~/.claude/rag-index
venv/bin/python report.py
```

**Done when:** Report read and zero-hit query count / stale chunk count noted.

## Score interpretation

Cosine similarity (0.0–1.0) measures how close a result is to the query. See [references/score-scale.md](references/score-scale.md) for the full scale and score component meanings (cosine, BM25, RRF).

## Run a test query

```bash
cd ~/.claude/rag-index
venv/bin/python query.py "your question here" --top 5 --scope-repo all
```

**Output example:**
```
Query: how do I write a skill in forgekit?

Results:
1. path: ~/.claude/skills/adt-rag-quality/SKILL.md
   rrf: 2.85, cos: 0.73, bm25: 8.2
   snippet: "---\nname: rag-quality\ndescription: Evaluate retrieval quality..."

2. path: /Volumes/External\ HD/Desenvolvimento/forgekit/packages/catalog/catalog/skills/adt-rag/SKILL.md
   rrf: 2.12, cos: 0.61, bm25: 7.1
   snippet: "# Creating a skill\n\nSkills in forgekit..."
```

**Done when:** Query returned top-5 results with cosine scores; quality judgment made (good vs. weak hit).

## Test with scope filters

Narrow the search to specific repositories or content types:

```bash
# Query only skill docs
venv/bin/python query.py "authentication patterns" --scope skills

# Query only code from the Lucky repo
venv/bin/python query.py "async request handler" --scope code --scope-repo Lucky

# Query plans and standards
venv/bin/python query.py "project roadmap" --scope plans,standards
```

Available scopes: `code`, `claude-mem`, `commit`, `skills`, `repo-docs`, `handoffs`, `plans`, `changelog`, `standards`, `codex`, `spec`

**Done when:** Scoped query completed; results quality verified against expected scope.

## Identify zero-hit queries

Zero-hits signal corpus gaps. Read the weekly report:

```bash
grep -A 50 "Zero-hit queries" ~/.claude/rag-index/weekly.md
```

Example output:
```
Zero-hit queries (cosine < 0.25):
- how do I set up DI containers in the service layer? (0 results, 0.0)
- what's the async/await pattern for error handling? (0 results, 0.0)
- naming convention for internal utilities? (1 result, 0.18)
```

**Next steps for each zero-hit:**
1. Does the corpus document this topic anywhere? (use `adt-rag-inspect` to audit)
2. If not → write a short standards doc, skill, or handoff explaining the topic
3. Reindex: `build.py --incremental <new-file>`
4. Re-test the query to verify it now returns good results

**Done when:** All recurring zero-hit queries identified and root cause assessed (corpus gap vs. rephrase needed).

## Quality metrics table

Use this checklist weekly. See [references/quality-metrics.md](references/quality-metrics.md) for the full tracking table and instructions on how to fill it in.

## Detect regressions

Compare this week's report to last week:

```bash
# Show chunk count over time
ls -lh ~/.claude/rag-index/weekly*.md

# Compare recent reports
diff <(grep "Total chunks" ~/.claude/rag-index/weekly.md | tail -1) \
     <(grep "Total chunks" ~/.claude/rag-index/weekly.2024-12-20.md | tail -1)
```

If chunk count dropped >5%, a full rebuild may have failed or a source was deleted.

**Done when:** Regression detection completed; chunk count / metric trends compared; any drops >5% flagged.

## Retest after improvements

After curating the corpus or reindexing, re-run the failing query:

```bash
venv/bin/python query.py "previously zero-hit question" --top 5
```

Expect cosine >0.40 after curation. If still <0.25, the added doc may not be specific enough — revise it or add more keywords.

**Done when:** Previously zero-hit query now returns cosine >0.40; OR root cause understood and next curation steps documented.

## See also

- `adt-rag-index-rebuild` — reindex after adding/updating corpus docs
- `adt-rag-curate` — fix zero-hit gaps by adding missing documentation
- `adt-rag-coverage` — audit corpus distribution (which source types are thin)
- `adt-rag-inspect` — examine what's actually in the index
