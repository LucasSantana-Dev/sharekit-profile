---
name: rag-curate
description: "Improve RAG corpus quality by adding missing docs, rewriting weak chunks, and filling retrieval gaps. Use after a diagnostic skill (rag-quality, adt-rag-coverage, adt-rag-drift) flags a coverage gap or when the index returns poor/irrelevant results for a known query."
triggers:
  - rag curate
  - curate corpus
  - improve rag
  - add to rag
  - rag coverage gaps
invocation_type: internal
---

# RAG Curate

Add missing docs or rewrite weak chunks after a diagnostic (`rag-quality`, `adt-rag-coverage`, `adt-rag-drift`) identifies a gap. Surgical alternative to a full rebuild.

## Corpus directories

| Type | Path |
|---|---|
| Skills | `~/.claude/skills/` |
| Standards | `~/.claude/standards/` |
| Plans | `~/.claude/plans/` |
| Codex | `~/.claude/codex/` |
| Handoffs | `~/.claude/handoffs/` |
| Code | tracked repos in `build.py` |

## Three curation patterns

### A. Missing doc → write + incremental reindex

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG index unreachable"; exit 1; }

cat > ~/.claude/standards/new-pattern.md <<'EOF'
# New Pattern Name
...
EOF

cd ~/.claude/rag-index
venv/bin/python build.py --incremental ~/.claude/standards/new-pattern.md
sqlite3 index.sqlite "SELECT COUNT(*) FROM chunks WHERE path LIKE '%new-pattern.md%';"
```

**Done when:** SELECT COUNT confirms >0 chunks indexed for the new doc.

**Stop if:** chunks count returns 0 — reindex failed or doc was filtered.

### B. Weak retrieval (cos <0.40) → rewrite

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG index unreachable"; exit 1; }

cd ~/.claude/rag-index
venv/bin/python query.py "your weak query" --top 3
# note path + chunk id; edit the source file to add keywords / clarify context
venv/bin/python build.py --incremental <path>
venv/bin/python query.py "your weak query" --top 3   # cosine should rise
```

**Done when:** cosine score ≥0.40 for the weak query in top 3 results.

**Stop if:** score remains <0.40 after rewrite — content may not address the gap.

### C. Undercovered repo → widen globs in build.py

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG index unreachable"; exit 1; }

sqlite3 ~/.claude/rag-index/index.sqlite \
  "SELECT repo, COUNT(*) FROM chunks WHERE repo='your-repo' GROUP BY repo;"
grep -n "your-repo" ~/.claude/rag-index/build.py
# add globs (e.g. add 'src/**/*.tsx'), then incremental reindex
```

**Done when:** chunk count for the repo increased; verify with `SELECT COUNT` after reindex.

**Stop if:** >100 chunks missing detected — use full rebuild via `~/.claude/rag-index/build.py` (full run) instead.

## Gap-filling cheatsheet

| Gap | Detection | Fix | Time |
|---|---|---|---|
| Missing doc | zero chunks for topic | write + incremental | 10 min |
| Weak retrieval | score <0.40 | rewrite + reindex | 15 min |
| Undercovered repo | <50 chunks, many files | widen globs + reindex | 20 min |
| Dead code chunks | orphaned (rag-drift) | sqlite DELETE + reindex | 5 min |
| Stale (sha mismatch) | rag-drift | reindex modified file | 5 min |

## When to stop and rebuild instead

**Stop if** any of these apply — curation is no longer the right tool:

- **>100 chunks missing** (detected in Pattern C) → full rebuild via `~/.claude/rag-index/build.py` (full run)
- **>20 stale chunks** (detected via `rag-drift`) → full rebuild
- **Many chunks <100 chars** → rebuild with adjusted chunk-size config in build.py

## Validation

After every curation:

```bash
cd ~/.claude/rag-index
venv/bin/python query.py "<original weak query>" --top 5   # cos > 0.40
venv/bin/python report.py                                   # check weekly delta
```

Commit any doc edits or new standards files to the appropriate repo.

## See also

- `adt-rag-coverage` — find gaps
- `rag-quality` — confirm curation worked (also checks chunk shape/quality)
- `adt-rag-drift` — detect stale chunks
- `~/.claude/rag-index/build.py` (full run, no `--incremental`) — full rebuild fallback
