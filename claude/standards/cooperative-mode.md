# Cooperative Mode - guest behavior in team repos

**Status:** active (defined 2026-07-24). Canonical answer to "how does the harness
behave in repos it does not own." Decision record: global ADR
`2026-07-24-cooperative-mode`.

The harness was built solo-first: full autonomy, cross-project memory, convention
rollouts. Those are features in personal repos and liabilities in team/employer/
third-party repos. Cooperative mode is the per-repo posture that makes the agent a
good citizen WITHOUT weakening solo mode elsewhere.

## Detection (who am I in this repo?)

`~/.claude/scripts/repo-mode.sh <dir>` prints `solo` or `cooperative`:

1. **Explicit marker wins:** `<repo-root>/.agents/mode` containing `cooperative`
   or `solo` (one word, first line). In team repos, gitignore it: it is a
   personal posture flag, not team configuration.
2. **Committer diversity (team default, outranks org ownership):** >=2
   non-operator, non-bot committers in the last 180 days => `cooperative`.
   Other people working here is decisive evidence, whatever the remote says.
   See `standards/multi-person-work-ethics.md` finding 2.4.
3. **Remote-owner heuristic:** owner in `<github-user>` or
   `<project-b>-Projects` => `solo`.
4. **No remote** => `solo` (local experiments are operator-owned).
5. **Anything else** => `cooperative` (secure default for unknown orgs).

Adjust the allowlist in the script if a long-term employer org deserves `solo`-adjacent
trust; prefer marking individual repos over widening the list.

## Behavior matrix

| Layer | Solo (default) | Cooperative |
|---|---|---|
| Autonomy | T0-T2 per tiers; T3 asks | T0/T1 only; merges, releases, mass actions, CI/workflow installs, convention changes = T3 ask-always |
| Recall injection (autorecall) | `--scope-repo all` (memory, plans, handoffs, ADRs included) | `--scope-repo <this repo>` (personal notes have no repo field, so they are excluded structurally) |
| Context pack | RAG pack on coding-intent prompts | skipped (`coop-skip` in the kill-gate log); repo-local graphify still allowed |
| Memory writes (sessionend/precompact) | project memory dir (often vault-symlinked, RAG-indexed) | redirected to `<project>/memory-coop` when the dir resolves into the vault; never RAG-indexed |
| Conventions | harness conventions roll out freely | repo's own AGENTS.md/CLAUDE.md/CONTRIBUTING/CI/commit-style/release-flow win; no harness artifacts (DECISIONS.md, docs/adr, dependabot/stale/release-please, hooks) unless explicitly asked |
| PR/release machinery | merge-confidently, ship, dep-sweep, release-please installers | read-only by default; act only on explicit ask, one PR at a time |
| Identity/disclosure | operator identity, no AI markers (house rule) | repo-configured git identity if set; follow the repo's AI-assistance norms |

## Why isolation is structural, not promissory

- The RAG index no longer ingests `~/.claude/projects/*/memory/` at all
  (ADR-0039, 2026-07-23); the vault is indexed directly. So project-local
  auto-memory never re-enters retrieval.
- The only remaining bleed channel was project memory dirs symlinked to the
  vault; the memory writers now redirect to `memory-coop` in cooperative repos.
- Personal notes carry no `repo` field in the index, so `--scope-repo <repo>`
  excludes them by construction (no filter list to maintain).

## Existing dials (no new code needed)

- `CLAUDE_RAG_AUTORECALL=off` — disable autorecall per shell.
- `CLAUDE_AUTO_CONTEXT_PACK=off` — disable the context pack per shell.
- Claude Code per-repo local settings (gitignored): `.claude/settings.local.json`
  can set `"autoMemoryEnabled": false` (or `"autoMemoryDirectory": "<work dir>"`),
  `"disableAllHooks": true` (nuclear), and per-repo `attribution` strings.
  Scopes: Managed > CLI > Local > Project > User
  (https://code.claude.com/docs/en/settings).
- `git includeIf` in `~/.gitconfig` for path-based identity separation, e.g.
  `[includeIf "gitdir:~/work/"] path = ~/.gitconfig-work` — set up when a real
  employer directory exists (follow-up, needs the work email).

## Failure modes / notes

- Worktree of a cooperative repo: the marker (if gitignored) is absent, but the
  remote-owner heuristic still resolves cooperative. Both paths land right.
- A repo that becomes cooperative mid-relationship: flip the marker; hooks apply
  from the next prompt/session.
- The mode only restricts PERSONAL content crossing repos. Repo-local knowledge
  (code, docs, graphify, repo-scoped RAG) stays fully available.
- Kimi sessions do not fire Claude hooks; the behavioral rules in
  `~/.kimi-code/AGENTS.md` ("Cooperative mode") are the guard there. Keep both
  layers aligned when editing either.

## Revisit when

- A real employer/client org onboards (then: git includeIf identity, possibly a
  second allowlist entry, review whether `memory-coop` notes deserve a
  work-namespaced RAG source).
- Claude Code adds native per-project hook disabling beyond `disableAllHooks`
  (then drop the script-internal guards for the cleaner mechanism).
