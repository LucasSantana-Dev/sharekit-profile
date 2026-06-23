# Directory Selection

## Preferred order

1. Reuse `.worktrees/` if it already exists.
2. Otherwise reuse `worktrees/` if it already exists.
3. Otherwise check project guidance such as `CLAUDE.md` or `AGENTS.md`.
4. If no guidance exists, choose a project-local hidden directory over a global fallback.

## Selection rules

- Prefer project-local paths when the repository already uses them.
- Avoid mixing local and global worktree roots for the same repository.
- Report the chosen directory explicitly before creating the worktree.
