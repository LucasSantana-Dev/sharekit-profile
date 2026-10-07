# Knowledge-Brain Standard (ADR-0029)

Canonical spec for every knowledge / memory / RAG / graph skill. The brain is the
single source of truth for memories and graph snapshots; this file is the single
source of truth for how skills interact with it. Memory is dated advice: verify
before acting, and on conflict with a rule or owner statement, memory loses.

Related: [[adr_0029_cross_project_shared_brain]], [[homelab_dashboard_audit_2026-06-18]].

## Paths (use these, no variants)

```
BRAIN="${DEV_ROOT:-$HOME/dev}/knowledge-brain"   # vault root
$BRAIN/memory/                       # memory .md files + MEMORY.md index
$BRAIN/graphs/<project>/graph.json   # per-project graph snapshots
SYM="$HOME/.claude/projects/-Volumes-External-HD-Desenvolvimento/memory"  # -> $BRAIN/memory
```

GitHub remote: `<github-user>/knowledge-brain`.

## 1. Mount guard: ALWAYS run before any brain/RAG op

The brain and the RAG embedder cache live on the External HD. Fail loud, never silent:

```bash
BRAIN="${DEV_ROOT:-$HOME/dev}/knowledge-brain"
if ! mount | grep -q "${DEV_ROOT:-$HOME/dev}" || [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: External HD not mounted, knowledge-brain unreachable." >&2
  exit 0   # in a hook; in a skill, surface the blocker as output and halt the phase
fi
```

"Drive unmounted" is a hard stop, not a reason to guess. `[ -f "$SYM/x.md" ]` false
during an unmount means unknown, not absent: never delete or reconcile on it.

## 2. Write via the symlink path

Memory writes target `$SYM/<name>.md`, not raw `$BRAIN/memory/`, so `reindex-hook.sh`
fires an incremental reindex. `build.py` resolves symlinks, so memories index under
the brain realpath: that is the canonical RAG path. Never dedup by deleting
brain-path chunks.

## 3. Push protocol

The SessionEnd `sync push-memories` hook commits and pushes. Push explicitly when
the session is not ending soon, or after a graph snapshot:

```bash
BRAIN="${DEV_ROOT:-$HOME/dev}/knowledge-brain"
git -C "$BRAIN" add memory/ graphs/ 2>/dev/null
git -C "$BRAIN" diff --cached --quiet || {
  git -C "$BRAIN" commit -q -m "chore: knowledge-brain sync from session" && git -C "$BRAIN" push -q
}
```

Graph snapshot: `cp <repo>/graphify-out/graph.json $BRAIN/graphs/<project>/` then push.
Skip if node count is unchanged.

## 4. Repository-as-SoT gate

A decision a future agent needs must be committed to the repo (ADR) AND captured in
the brain. Do not exit a knowledge workflow with uncommitted agent-actionable context.

## 5. Graph-first discipline (when `graphify-out/graph.json` exists in the repo or a parent root)

- Run `graphify query "<question>" --budget 500` BEFORE wide Grep/Read. Fall back to
  Grep/Read only for what the graph does not answer, and read narrowly (files/lines it cited).
- A `# Knowledge graph context` block injected by `auto-context-pack` is the primary
  map: do not re-derive it by reading files.
- Use `graphify path A B` / `graphify explain NODE` instead of multi-file reads for relationships.
- Keep it fresh: after significant code changes run graphify `--update` (code-only
  uses AST extraction, free). Batch doc changes (semantic re-extraction).
- graphify ignores `.gitignore`/`.claude` excludes and has no `--exclude` (ADR-0036).
  Prune agent worktrees (`git worktree prune`, remove dead dirs under
  `${EXTERNAL_HD}/Desenvolvimento/.worktrees/`) before `graphify update`. For
  structural code-nav on a polluted graph prefer codebase-memory-mcp.

### codebase-memory-mcp (cmm)

- Graphs are machine-local and regenerable (`~/.cache/codebase-memory-mcp/<project>.db`);
  they do not travel between machines. The path is on-demand re-index
  (`cbm-session-reminder` hook says: run `index_repository` first if not indexed).
- `index_repository(persistence:true)` is a no-op in cmm 0.34.x: do not rely on a
  portable `.codebase-memory/graph.db.zst` artifact.
- Storage: stays under `$HOME` while <100MB; above that move to External HD with a
  symlink, only with the MCP server stopped (open SQLite risks corruption).

## 6. RAGLight (Phase 2, deferred)

Cross-project semantic recall will be a RAGLight MCP exposing `search_knowledge`
(`FolderLoader` over `$BRAIN/memory/`, e5-small per ADR-0028). Until live, `recall`
uses the local RAG index (covers `$BRAIN/memory` via the symlink glob); cross-project
reads are grep/read against the vault.

## Conformance checklist (every knowledge/memory/RAG skill)

- [ ] Mount-guards before brain/RAG ops (section 1)
- [ ] Uses canonical paths, no hardcoded variants
- [ ] Writes memory via `$SYM` (section 2)
- [ ] Pushes memory/graph changes (section 3) when not session-end
- [ ] Queries the graph first when one exists (section 5)
- [ ] References this standard instead of duplicating the rules
