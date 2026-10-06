# Workflow

## Default sequence

1. Detect scope.
2. Read local guidance.
3. Check what is already in flight.
4. Choose the highest-value safe next action.
5. Decompose: if the work has 2+ independent units, dispatch them as parallel agents (see Parallel execution), do NOT run them sequentially in the main context.
6. Execute the smallest coherent step (or fan out).
7. Verify with repo-native checks, narrowest meaningful check first.
8. Merge or ship only when ready.
9. Leave a checkpoint.

## Startup sequence

For any non-trivial task:

1. Detect repo, branch, worktree.
2. Check handoffs: `~/.claude/skills/handoff/bin/handoffs list`; with several open, ask which one, never guess (other sessions own the others); legacy `<project>/latest.md` only when the list is empty. After /compact the SessionStart hook re-injects this session's facts and the auto-handoff.
3. Read local guidance: `CLAUDE.md`, `README.md`, `.claude/plans|tasks|standards/`, `.agents/memory/` (including `.agents/memory/in-progress.md` if present), and the latest plan in `.claude/plans/` or `.agents/plans/`.
4. Pick workflow or skill.
5. State scope, worktree, workflow, objective, first evidence source. Begin.

Once the right handoff is chosen, continue from its stated next action. A clean working tree is not proof that work is complete.

## Durable execution

- Continue until the active plan is complete or a real blocker is reached.
- If blocked, capture the blocker and the exact next action.
- Never abandon in-flight work without a handoff, plan update, or task note.
- Prefer durable state (handoffs, plans, task files) over session memory.

## Research and spec before execution

Every non-trivial task starts with research and a spec, not code: `landscape-scan` when what to build is the question, `spec-research` when the task is known. Searching for a DESIGN fact mid-task (API shape, library behavior, protocol constraint) is a defect signal: loop back and fix the spec, do not research ad hoc mid-implementation. Runtime diagnostics (errors, logs, failing tests) are debugging, not design research, and stay mid-task.

## Branching and merge

- Use `feature/`, `fix/`, `refactor/`, `chore/`, `docs/`, `ci/`, or `release/` prefixes.
- Never push directly to `main`. Prefer small, reviewable PRs.
- Never merge until all required checks are green or a failure is proven unrelated.
- Never use admin overrides or bypass branch protection to hide unresolved delivery problems.

## Parallel execution (MANDATORY)

One rule: dispatch parallel agents whenever the work has 2+ independent units. A unit is independent if its inputs do not depend on another unit's output. Typical cases: multi-repo or multi-PR sweeps, fan-out investigations, self-contained batch edits, independent research or lookups, independent diagnostics on one repo, phased-plan tasks (`/parallel-phases`).

One exemption: run inline when the whole task is under 3 reads and under 2 edits. Single-unit work and strict sequential dependencies are not parallelizable by definition.

Running independent units sequentially in the main context is a contract violation. If you catch yourself about to run the second of N independent units serially, stop, re-dispatch the rest as parallel `Agent()` calls in one block, and tell the user. Never ask whether to parallelize.

### Dispatch mechanics

1. Single tool-use block: all `Agent()` calls in ONE assistant message.
2. Self-contained child prompts: agents start cold; pass only what the unit needs, never the full conversation. If a child needs conversation state, use a fork, not a context dump.
3. Summary-only returns (about 2k tokens or less): raw dumps and file contents stay in the child.
4. Agent type: `Explore` for read-only search, `general-purpose` for multi-step research, `code-reviewer`/`critic`/`security-reviewer` for review, `test-engineer` for tests, `debugger`/`tracer` for root-cause hypotheses, domain specialists for their domains.
5. Reconcile: the main context synthesizes returns and decides the next step; never pass agent output verbatim to the user.
6. Do not add further gates or thresholds to this rule.

### Worktrees

A worktree is required only for write-capable agents when 2+ agents touch the same repo: one each, at `${DEV_ROOT}/.worktrees/<task>-<n>/` (via `EnterWorktree` or `git worktree add`). Read-only agents (`Explore`, `Plan`, `critic`, `code-reviewer`, `security-reviewer`, `document-specialist`, `explore`) share the checkout.

- Never use `~/.claude/worktrees/` or internal-disk paths. If `${DEV_ROOT}` is unmounted, halt and tell the user.
- After agents finish, `git worktree remove` those merged or abandoned; keep only in-flight ones.

### Anti-patterns

- Sequential Read() calls that could be one parallel batch.
- Auditing N repos by `cd`-ing into each in turn.
- Running independent diagnostics (`/test-health`, `/config-drift-detect`, `/coverage-gap`) in series.
- Two write-capable agents on the same checkout.

## Harness-native tools (prefer over skills/scripts)

- **Workflow tool**: deterministic multi-agent orchestration (pipelines, fan-out, adversarial verify, budget loops). Local, token cost only. Requires user opt-in ("use a workflow" / "ultracode") unless a skill mandates it. Analysis stages MUST set a read-only `agentType` per agent-routing.md. It slots inside composite phases; it never replaces a composite.
- **Monitor tool**: stream background events (logs, CI, dev servers) and react live; supersedes poll-sleep loops.
- **/schedule (Routines)**: cloud agents on cron/event triggers. BILLED, counts toward the $25/month cloud ceiling. NEW recurring tasks only (not on launchd today AND needing off-Mac execution). Never migrate existing launchd jobs. Schedule 22:00-06:00 BRT.
- **/code-review ultra**: cloud multi-agent review, user-triggered, BILLED (same ceiling). High-stakes diffs to main/release only; note in memory which PRs used it.
- **/fast**: Opus with faster output at a price premium. A speed lever, not a tier. Mechanical work runs on Sonnet; Haiku is retired as of 2026-09-17.
- **Effort levels (Opus 4.8+)**: `xhigh` for architecture/ADR reasoning only; default otherwise.
