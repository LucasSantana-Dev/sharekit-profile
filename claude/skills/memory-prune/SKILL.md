---
name: memory-prune
description: Audit project memory files for stale entries — items where the cited PR is merged, the cited bug is fixed, the cited file/function no longer exists, or the gotcha was patched out of the codebase. Proposes archival or deletion per entry. Read-only by default; prompts before any change. Use periodically (monthly) or when memory recall starts surfacing entries that contradict current code. Pair with `sync-memories` (write fresh notes) and `adt-rag-drift` (which handles the RAG index, not the memory files themselves).
triggers:
  - prune memory
  - audit memory
  - clean stale memories
  - memory hygiene
  - memory is stale
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/memory-prune
---

# memory-prune

Project memory files at `~/.claude/projects/<encoded-cwd>/memory/*.md` accumulate `feedback_*` and `project_*` notes faster than they decay. Entries cite PRs that have merged, branches that have been deleted, gotchas that have been patched. Future sessions follow them as if they were still current and waste effort re-discovering they're not.

This skill audits the memory dir, classifies each entry, and proposes archival.

## When NOT to run

- Memory dir has <10 files → noise budget is low; not worth auditing.
- All entries are <30 days old → too soon to expire anything.
- A `memory-prune` audit ran in the last 30 days and was acted on → nothing has aged out yet.
- The user is mid-task → don't archive entries you might cite minutes later.

## Inputs

- **Memory dir** (auto-detected from `$PWD`): `~/.claude/projects/$(pwd | tr '/' '-' | sed 's/^-//' | sed 's/^/-/' )/memory/`
- **MEMORY.md index** (in same dir): the human-readable index that points at each file
- **Repo for cite-validation** (auto-detected from `gh repo view`): used to query PR / branch / commit state

## Classification rules

For each `*.md` file in the memory dir, read its frontmatter + body and classify:

| Verdict | Trigger | Action |
|---------|---------|--------|
| **archive** | Cited PR is `MERGED` AND the gotcha was patched as part of that PR | Move to `memory/archive/<YYYY-MM-DD>-<file>.md` |
| **archive** | Cited branch no longer exists on origin | Move to archive |
| **archive** | Cited file:line points to a file that no longer exists | Move to archive |
| **archive** | Cited PR is `MERGED` AND entry is `type: project` (status update, not a durable lesson) | Move to archive |
| **keep** | `type: feedback` — durable lessons (gotchas, patterns) survive PR merges | Keep |
| **keep** | `type: reference` — pointers to external resources | Keep unless URL 404s |
| **keep** | `type: user` — identity/role; never expire | Keep |
| **update** | `type: project` PR is `MERGED` but the entry still says "open" / "WIP" | Edit to mark merged + add merge SHA, then keep |
| **flag-for-user** | Ambiguous — cited evidence partially resolved, partially open | List for manual review |

**Hard rule:** never auto-delete. Move to `archive/` so the chunk remains in the RAG index but visibly stale-tagged.

## Workflow

### Phase 1 — Discover
```bash
MEM_DIR=~/.claude/projects/$(pwd | sed 's|^/||' | tr '/' '-' | sed 's/^/-/')/memory
ls -1 "$MEM_DIR"/*.md 2>/dev/null | wc -l                # total entries
ls -1t "$MEM_DIR"/*.md | head -5                          # newest 5
ls -1tr "$MEM_DIR"/*.md | head -5                         # oldest 5
```

### Phase 2 — Classify (one pass per file)
For each file, parse frontmatter (`type`, `name`) and body. Extract cites:

- **PR refs**: `#NNN`, `PR #NNN`, `pr/NNN`, URLs containing `/pull/NNN`
- **SHA refs**: 7+ hex chars in commit-context
- **Branch refs**: `branch_name` or `feature/...` patterns
- **File:line cites**: `path/to/file.ts:NNN`

Run validation:
```bash
# PR state
gh pr view <NNN> --repo <owner>/<repo> --json state,mergedAt --jq '.state, .mergedAt'

# Branch existence
git ls-remote --heads origin <branch_name>

# File existence
[ -f <repo>/<path> ] && echo exists || echo missing
```

Cache results — many entries cite the same PR.

### Phase 3 — Propose
Output one section per verdict:

```
MEMORY PRUNE AUDIT — <project> · <YYYY-MM-DD>

Total entries: <N>
Audit window: <newest age>d - <oldest age>d

Archive (cited evidence resolved):
  · <file>.md — PR #NNN merged YYYY-MM-DD; lesson encoded in commit <SHA>
  · <file>.md — branch <name> deleted; entry no longer applies
  · <file>.md — type:project PR merged; status is now historical

Update (mark resolved, keep durable lesson):
  · <file>.md — change "PR #NNN open" → "PR #NNN merged at <SHA>"

Flag for manual review:
  · <file>.md — partial resolution; user judgment needed

Keep (no change):
  · <N> entries — durable feedback / reference / user notes
```

### Phase 4 — Confirm + execute (only on user OK)
Stop here unless the user says "go" / "archive these" / "do it":

```bash
mkdir -p "$MEM_DIR/archive"
for f in <files-to-archive>; do
  base=$(basename "$f")
  mv "$f" "$MEM_DIR/archive/$(date +%Y-%m-%d)-$base"
done
```

### Phase 5 — Update MEMORY.md index
For each archived file, remove or comment-out its line in `MEMORY.md`. For each updated file, regenerate its summary line. Never leave dangling links.

### Phase 6 — Reindex RAG
```bash
cd ~/.claude/rag-index
for f in <changed-files>; do venv/bin/python build.py --incremental "$f"; done
```

Archived files keep their old chunks under their new path so the lesson survives recall but is visibly aged. Optional: bump the chunk's source-type tag to `memory-archive` so quality skills can deprioritize.

## Output template

```
MEMORY PRUNE — <project> · <date>

Stats:
  total: <N>
  archived: <N>
  updated: <N>
  flagged: <N>
  kept: <N>

Archived (with reason):
  · <file> — <one-line reason>

Updated:
  · <file> — <field changed>

Flagged for review:
  · <file> — <ambiguity>

Next:
  Run /knowledge-loop to confirm recall still works on durable lessons.
```

## Hard rules

- **Read-only by default.** Phase 4 requires explicit user confirmation. Never archive in a single pass.
- **Never delete a memory file.** Move to `archive/` so the chunk is preserved but visibly stale.
- **`type: feedback` is durable.** A lesson learned from PR #NNN survives PR #NNN's merge — don't archive feedback just because its origin PR shipped.
- **Cite-validate every claim.** A "PR merged" verdict requires `gh pr view --json state` to actually return `MERGED`, not a parsed assumption.
- **Cap scope to one project per run.** Cross-project audits dilute focus and inflate context.
- **Don't auto-update MEMORY.md** without showing the diff first.

## Pair with

- `sync-memories` — after pruning, capture any new lessons from the audit itself.
- `knowledge-loop` — composite that runs recall → capture → curate → handoff; pairs with prune at session boundaries.
- `adt-rag-drift` — handles the RAG index drift; this skill handles the memory **files**.
- `rag-curate` — fix weak retrievals exposed when stale entries are pruned and the new query surface widens.

## Examples of stale entries (example project)

These were the kind of entries this skill catches:

- `project_autoplay_pr817.md` cited PR #817 as "merged"; useful while PR was open, now historical → archive after some grace period.
- `feedback_pr821_rebase_conflicts.md` is `type: feedback` — durable lesson about long-lived branches; **keep regardless of PR #821's state**.
- `project_test_cleanup_phase2_2026-05-09.md` cited 3 stacked branches with specific test counts; once the phase is done, the counts are historical → update to "Phase 2 complete: -23 tests" + archive.

## References

- Memory dir: `~/.claude/projects/<encoded-cwd>/memory/`
- Index file: same dir, `MEMORY.md`
- RAG reindex: `~/.claude/rag-index/build.py --incremental <file>`
