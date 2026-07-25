# Recall Routing — Which Query to Use

The `recall` skill documents three knowledge sources + their decision table. Rather than duplicate that guide here, **use `recall` as the canonical routing source**.

## Quick decision

- **"What did we decide" (any project)** → use `search_knowledge` (vault-scoped, cross-project).
- **"Why was this written this way" or repo-specific decision** → use `rag_query(scope_types=["memory","handoffs"])`.
- **"Did we hit this bug before" or past reasoning** → parallel: `search_knowledge` + claude-mem in one call.
- **"Where is function X defined" or call graph** → use Serena `find_symbol` + `find_referencing_symbols`.

**Before any query:** Mount guard (references/mount-guard.sh). If External HD unmounted, `rag_query` and `search_knowledge` fail; fall back to claude-mem + grep only.

## See also

- `~/.claude/skills/recall/SKILL.md` — full decision table + parallel fan-out patterns.
- `standards/knowledge-brain.md §5` — when RAGLight lands, this routing may shift.
