# Storage policy — Macintosh HD is space-constrained

The internal disk runs near capacity. All new development and AI artifacts MUST live on the External HD.

- Default location for new repos, clones, and worktrees: `${DEV_ROOT:-$HOME/dev}/<repo>`. Worktrees: `${DEV_ROOT:-$HOME/dev}/.worktrees/`.
- Default location for AI tool data dirs, datasets, model weights, vector indexes, and large caches when the tool allows: `${DEV_ROOT:-$HOME/dev}/`.
- Never `git clone`, `git worktree add`, `mkdir`-a-new-project, or download datasets/weights into `~/` or any path under `~/` outside of `~/.claude`, `~/.codex`, `~/.config`, or other tool-config dirs that legitimately must live in `$HOME`.
- If a tool insists on writing data under `$HOME` and the data grows beyond ~100MB, after first run move the directory to External HD and replace the original with a symlink.
- Before creating a new directory under `~/Desenvolvimento`, prefer creating it on External HD and symlinking back, e.g. `ln -s "${DEV_ROOT:-$HOME/dev}/<repo>" ~/Desenvolvimento/<repo>`.
- If `${DEV_ROOT:-$HOME/dev}` is not mounted, surface that to the user before creating dev artifacts on internal disk.

## Amendment 2026-08-31 — hot-repo exception (operator-directed)

Internal disk went 96% -> 84% after `disk-cleanup` reclaimed ~48G of local TM
snapshots. The operator moved three I/O-hot repos to the internal SSD for speed
(measured 652 MB/s external vs 4.543 MB/s internal on the same 2.1GB sqlite;
external runs stalled 2+ min in I/O wait under corespotlightd contention):

- `~/Desenvolvimento/observatorio-rcc`, `~/Desenvolvimento/rcc-brain`,
  `~/Desenvolvimento/knowledge-brain` are now REAL directories on internal disk.
- Their old paths under `${DEV_ROOT:-$HOME/dev}/` are symlinks
  pointing back at them (the REVERSE of the rule above). Do not "fix" these
  symlinks or move the repos back without operator direction.
- Everything else keeps following the default rule: new repos, worktrees,
  datasets, weights go to External HD. The exception is only for repos the
  operator explicitly designates as I/O-hot, and only while internal capacity
  stays comfortably above ~40G free.
- launchd note: `StandardOutPath` on External HD fails with EX_CONFIG (78)
  (memory note gotcha_graph_refresh_achava_zero_repos_2026-08-28: dated advice, verify before acting). Internal-real +
  external-symlink is the launchd-safe direction.
