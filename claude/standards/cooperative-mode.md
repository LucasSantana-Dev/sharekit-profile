# Cooperative Mode: guest behavior in team repos

**Status:** active (defined 2026-07-24). Canonical answer to "how does the harness
behave in repos it does not own", and the ethics rules for agents acting on
repositories other people depend on. Decision records: global ADRs
`2026-07-24-cooperative-mode`, `2026-07-24b-multi-person-work-ethics`.

Solo-first autonomy and cross-project memory are features in personal repos and
liabilities in team, employer or third-party repos. Cooperative mode is the per-repo
posture that makes the agent a good citizen without weakening solo mode elsewhere.

## Ethics rules (apply to any repo other people may depend on, whoever owns the remote)

1. **Absence of objection is not approval.** Every autonomous action must name the
   positive signal that authorized it. "No one said no" is not one.
2. **Engagement-triggered guards are floors, not policies.** "Never automate on a PR
   someone else touched" is blind to unreviewed work. Name it as a floor when citing it.
3. **Unenforced review expectation = WAIT + finding.** "No required reviewers
   configured" never resolves to SKIP. Surface the finding, ideally fix the protection.
4. **Team behavior is the standing default.** Detection may tighten on evidence
   (committer diversity), never relax on absence of evidence.
5. **Merging to a shared branch is a social act.** It requires a human, categorically;
   no critic pass substitutes. Direct pushes to shared branches are the same category;
   use PRs.
6. **No phantom guardrails.** A rule claiming mechanical enforcement must name an
   artifact that exists (harness-vitals check 12 verifies this set). Aspirational
   rules must say they are instructions, not guardrails.
7. **Governing doc and cited standard must agree.** Divergence is a defect; reconcile
   at the source.
8. **Keep gates rare.** Tighten only irreversible or socially consequential actions,
   batch escalations into one decision, proceed autonomously elsewhere.

Enforcement map: rules 1, 3, 5 = AGENTS.md hard rules plus the cooperative autonomy
caps below; rule 2 = AGENTS.md "FLOOR" annotation on the other-person-PR rule; rule 4 =
`repo-mode.sh`; rule 6 = harness-vitals check 12; rule 8 = cooperative mode escalates
only outward/social actions.

Audit checklist: team default with no per-repo opt-in; merges and direct pushes to
shared branches need a human; unenforced review = WAIT + finding; branch protection
verified and reported per repo before any merge in cooperative repos (partial: solo
repos have CodeRabbit required checks); enforcement claims name existing artifacts;
aspirational rules labeled; docs and standards agree; escalations rare and batched.

## Detection (who am I in this repo?)

`~/.claude/scripts/repo-mode.sh <dir>` prints `solo` or `cooperative`:

1. **Explicit marker wins:** `<repo-root>/.agents/mode` containing `cooperative` or
   `solo` (one word, first line). In team repos, gitignore it (personal flag).
2. **Committer diversity (outranks org ownership):** >=2 non-operator, non-bot
   committers in the last 180 days => `cooperative`.
3. **Remote-owner heuristic:** owner `<github-user>` or `<project-b>-Projects` => `solo`.
4. **No remote** => `solo`.
5. **Anything else** => `cooperative` (secure default for unknown orgs).

Prefer marking individual repos over widening the owner allowlist.

## Behavior matrix

| Layer | Solo (default) | Cooperative |
|---|---|---|
| Autonomy | T0-T2 per tiers; T3 asks | T0/T1 only; merges, releases, mass actions, CI/workflow installs, convention changes = T3 ask-always |
| Recall injection (autorecall) | `--scope-repo all` | `--scope-repo <this repo>` (personal notes have no repo field, so they are excluded structurally) |
| Context pack | RAG pack on coding-intent prompts | skipped (`coop-skip` in the kill-gate log); repo-local graphify still allowed |
| Memory writes (sessionend/precompact) | project memory dir (often vault-symlinked, RAG-indexed) | redirected to `<project>/memory-coop` when the dir resolves into the vault; never RAG-indexed |
| Conventions | harness conventions roll out freely | repo's own AGENTS.md/CLAUDE.md/CONTRIBUTING/CI/commit-style/release-flow win; no harness artifacts (DECISIONS.md, docs/adr, dependabot/stale/release-please, hooks) unless explicitly asked |
| PR/release machinery | merge-confidently, ship, dep-sweep, release-please installers | read-only by default; act only on explicit ask, one PR at a time |
| Identity/disclosure | operator identity, no AI markers (house rule) | repo-configured git identity if set; follow the repo's AI-assistance norms |

Isolation is structural: the RAG index does not ingest `~/.claude/projects/*/memory/`
(ADR-0039); memory writers redirect to `memory-coop` in cooperative repos; personal
notes carry no `repo` field so `--scope-repo <repo>` excludes them by construction.

## Dials

- `CLAUDE_RAG_AUTORECALL=off`: disable autorecall per shell.
- `CLAUDE_AUTO_CONTEXT_PACK=off`: disable the context pack per shell.
- Per-repo `.claude/settings.local.json` (gitignored): `"autoMemoryEnabled": false`
  (or `"autoMemoryDirectory"`), `"disableAllHooks": true` (nuclear), per-repo
  `attribution`. Scopes: Managed > CLI > Local > Project > User.
- `git includeIf` in `~/.gitconfig` for path-based identity separation (set up when a
  real employer directory exists; needs the work email).

## Notes

- Worktree of a cooperative repo: gitignored marker is absent, but the committer and
  remote-owner rules still resolve cooperative.
- Flipping the marker applies from the next prompt/session.
- The mode only restricts PERSONAL content crossing repos. Repo-local knowledge (code,
  docs, graphify, repo-scoped RAG) stays available.
- Kimi sessions do not fire Claude hooks; `~/.kimi-code/AGENTS.md` ("Cooperative
  mode") is the guard there. Keep both aligned when editing either.
- Revisit when a real employer/client org onboards (includeIf identity, allowlist,
  work-namespaced source for `memory-coop`) or Claude Code adds native per-project
  hook disabling.
