# Graph-first token discipline (loaded on demand when a graph exists)

If `graphify-out/graph.json` exists in the active repo (or a parent project root):

- **Query the graph BEFORE wide exploration.** For any codebase question ("how does X work", "what calls Y", "where is Z handled"), run `graphify query "<question>" --budget 500` first. Only fall back to Grep/Read sweeps for what the graph doesn't answer — then read narrowly (specific files/lines the graph cited).
- The `auto-context-pack` hook already injects graph context on coding prompts; when a `# Knowledge graph context` block is present in the prompt, treat it as the primary map and do not re-derive it by reading files.
- **Keep the graph fresh, cheaply.** After significant code changes, run the graphify `--update` flow — code-only changes use AST extraction (no LLM, free). Doc changes need semantic re-extraction; batch those.
- Use `graphify path A B` / `graphify explain NODE` instead of multi-file reads when tracing relationships.

Rationale: a budgeted graph query costs ~500 tokens; the file-read sweep it replaces typically costs 10-50k. `rtk read` compresses output ~13%; not reading the file at all saves 100%.

## Gotcha — graphify does NOT honor `.gitignore`/`.claude` excludes (ADR-0036)

`graphify update <path>` indexes EVERYTHING under the path, including `.claude/worktrees/agent-*/`
copies (it added 1156 duplicate worktree nodes to a sharekit graph). There is no `--exclude` /
`.graphifyignore` flag (verified, graphify 0.8.14). Until upstream adds one:
- **Prune agent worktrees before `graphify update`** (`git worktree prune` + remove dead dirs under
  `${EXTERNAL_HD}/Desenvolvimento/.worktrees/`), so duplicates aren't indexed.
- If duplicates are already in a graph, they inflate BFS/`query` noise — prefer codebase-memory-mcp
  for structural code-nav (it excludes `.claude`/worktrees by default; see ADR-0036 scoped-hybrid).
- This is an upstream graphify limitation, not a config we can set — re-evaluate if graphify ships an ignore mechanism.

## codebase-memory-mcp (cmm) — cross-machine + storage (ADR-0036 risk RESOLVED)

cmm graphs are **machine-local and regenerable**, stored as per-project SQLite at
`~/.cache/codebase-memory-mcp/<project>.db` (XDG cache; ~20M for sharekit+forgekit, grows with
repos indexed). They do NOT travel between machines (unlike a committed `graphify-out/graph.json`).
Resolution of the "not synced" risk:
- **On-demand re-index is the path, and it's already automated**: the `cbm-session-reminder`
  SessionStart hook instructs "if a project is not indexed in cmm yet, run index_repository FIRST."
  On a new machine the graph simply gets rebuilt on first code-nav use — re-index is **cheap**
  (seconds; forgekit's 11.8k nodes indexed in seconds). So no cross-machine sync is needed.
- **`index_repository(persistence:true)` is a NO-OP in this build** (2026-06-24, cmm 0.34.x): it
  does NOT write the advertised `.codebase-memory/graph.db.zst` portable artifact (verified in fast
  AND moderate mode). So artifact-sharing is not currently a viable bootstrap path — rely on re-index.
- **Storage policy**: the cache lives under `$HOME` (internal disk). It's regenerable and currently
  <100MB, so it stays put; **move `~/.cache/codebase-memory-mcp` → external drive + symlink once it
  exceeds ~100MB** (CLAUDE.md storage policy). Don't move it while the MCP server is running (open
  SQLite → corruption); do it server-stopped, and a stale/lost cache just re-indexes.
