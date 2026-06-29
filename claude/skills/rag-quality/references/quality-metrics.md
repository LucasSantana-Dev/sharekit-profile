# Quality Metrics Checklist

Track these metrics weekly to monitor RAG system health:

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Zero-hit queries (recurring) | <5 per week | — | — |
| Avg cosine (all queries) | >0.50 | — | — |
| Stale chunks | <20 | — | — |
| Total chunks | ≥14,000 | 14,355 | ✓ |
| Skills coverage | ≥500 chunks | — | — |
| Handoffs coverage | ≥200 chunks | — | — |

## How to fill in

Run the report generator and inspect the output:

```bash
cd ~/.claude/rag-index
venv/bin/python report.py
cat ~/.claude/rag-index/weekly.md
```

Then extract the "Current" values from the report and update the table above.
