# Storage policy — Macintosh HD is space-constrained

The internal disk runs near capacity. All new development and AI artifacts MUST live on the external drive.

- Default location for new repos, clones, and worktrees: `${DEV_ROOT}/<repo>`. Worktrees: `${DEV_ROOT}/.worktrees/`.
- Default location for AI tool data dirs, datasets, model weights, vector indexes, and large caches when the tool allows: `${DEV_ROOT}/`.
- Never `git clone`, `git worktree add`, `mkdir`-a-new-project, or download datasets/weights into `~/` or any path under `~/` outside of `~/.claude`, `~/.codex`, `~/.config`, or other tool-config dirs that legitimately must live in `$HOME`.
- If a tool insists on writing data under `$HOME` and the data grows beyond ~100MB, after first run move the directory to external drive and replace the original with a symlink.
- Before creating a new directory under `~/Desenvolvimento`, prefer creating it on external drive and symlinking back, e.g. `ln -s "${DEV_ROOT}/<repo>" ~/Desenvolvimento/<repo>`.
- If `${DEV_ROOT}` is not mounted, surface that to the user before creating dev artifacts on internal disk.
