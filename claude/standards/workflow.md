# Workflow

## Default sequence

1. Detect scope.
2. Read local guidance.
3. Check what is already in flight.
4. Choose the highest-value safe next action.
5. **Decompose**: if the work has ≥2 independent units, dispatch them as parallel agents with worktrees (see below) — do NOT execute them sequentially in the main context.
6. Execute the smallest coherent step (or fan out).
7. Verify with repo-native checks.
8. Merge or ship only when ready.
9. Leave a checkpoint.

## Branching

- Use `feature/`, `fix/`, `refactor/`, `chore/`, `docs/`, `ci/`, or `release/` prefixes.
- Never push directly to `main`.
- Prefer small, reviewable PRs.

## Merge rule

Never merge until all required checks are green or a failure is proven unrelated.
Do not use admin overrides or bypass branch protection to hide unresolved delivery problems.

## Parallel execution (MANDATORY)

When work decomposes into independent units, sequential execution in the main context is a contract violation. Dispatch in parallel.

### When parallel execution is REQUIRED

A unit-of-work is "independent" if its inputs do not depend on another unit's output. Triggers:

- **Multi-repo / multi-PR sweeps** — auditing, fixing, or updating N repos or N PRs.
- **Fan-out investigations** — answering the same question across N files / services / branches.
- **Batch edits** — applying the same change to N files where each edit is self-contained.
- **Cross-cutting research** — independent doc lookups, codebase searches, or external API queries.
- **Composite skill phases** with ≥3 independent tasks in a single phase (use `/parallel-phases`).
- **Pre-implementation analysis** — running `audit-deep`, `ecosystem-health`, `repo-state-snapshot` together for the same repo.

### When parallel is NOT required

- Single-unit work (one bug, one file, one decision).
- Trivial scope: <3 file reads OR <2 edits total.
- Strict sequential dependencies (output of A is input to B).
- Work where every unit needs the same in-context state already loaded.
- Analysis subtasks whose expected combined tool output is trivially small (<~5k tokens) — run inline (token-economics gate 4).

### Token-economics gates (ADR 2026-07-01-parallel-mandate-token-economics)

Dispatch that passes the independence test must ALSO respect these gates — they cut the 2–4× context-duplication penalty on analysis fan-outs without losing the parallelism guard rail:

1. **Self-contained child prompts** — pass only what the unit needs; never paste full conversation context into a child.
2. **Summary-only returns** — child final output is a summary (≤~2k tokens). Raw tool dumps, file contents, and transcripts stay in the child's context; the parent gets conclusions.
3. **Fork-first** — if a child genuinely needs the conversation state, use a fork (inherits parent context via cache) instead of a fresh agent fed a context dump.
4. **Inline small analysis** — see exemption above.

Do NOT add further gates when these feel insufficient — that's the complexity-collapse path. If the gates decay into dead code (see ADR revisit triggers), the designated fallback is inverting the default (inline unless ≥3 units or per-unit tool output >20k), not more gates.

### Dispatch mechanics

1. **Single tool-use block**: send all `Agent()` calls in ONE assistant message. Multiple messages = serial = violation.
2. **One worktree per repo-touching agent**: when ≥2 parallel agents will read or write the same repo, each gets its own git worktree at `${DEV_ROOT}/.worktrees/<task>-<agent-n>/`. Use `EnterWorktree` (per-session isolation) or `git worktree add` directly. Do not point multiple agents at the same checkout — index lockfile contention and branch-state races silently corrupt work.
3. **Pick the right agent type**:
   - `Explore` for read-only search/lookup
   - `general-purpose` for multi-step research
   - `code-reviewer` / `critic` / `security-reviewer` for review fan-out
   - `test-engineer` for test work
   - `debugger` / `tracer` for parallel root-cause hypotheses
   - Specialized agents (`forge-patterns-expert`, `mcp-gateway-specialist`, etc.) for their domains
4. **Brief each agent fully**: agents start cold. Self-contained prompts only — they cannot see prior conversation.
5. **Reconcile**: after parallel agents return, the main context summarizes findings and decides next step. Do not pass agent output verbatim to the user — synthesize.

### Worktree hygiene

- Naming: `<short-task>-<n>` (e.g. `auth-refactor-1`, `auth-refactor-2`).
- Location: `${DEV_ROOT}/.worktrees/` (NEVER `~/.claude/worktrees/` or internal-disk paths — see CLAUDE.md storage policy).
- After parallel agents finish: `git worktree remove` the ones whose work was merged or abandoned. Keep only worktrees with in-flight changes.
- If `${DEV_ROOT}` is unmounted, halt and tell the user rather than falling back to internal disk.

### Refusal pattern

If you catch yourself about to execute the second of N independent units sequentially in the main context: stop, re-dispatch all remaining units as parallel `Agent()` calls in a single tool-use block, and tell the user you corrected the approach. Do not silently continue serial execution.

### Anti-patterns

- ❌ Three Read() calls on three files in three separate assistant turns when reading them in parallel would do.
- ❌ Auditing 6 repos by `cd`-ing into each one sequentially. Use `Agent()` × 6 with worktrees.
- ❌ Running `/test-health`, `/config-drift-detect`, `/coverage-gap` in series when they're independent diagnostics. Fan out.
- ❌ Two parallel agents pointed at the same `~/Desenvolvimento/<repo>` checkout. Worktree each.
- ❌ Asking the user "should I do these in parallel?" when the rule already mandates it — just do it.

## Harness-native tools (use before reaching for skills/scripts)

The Claude Code harness ships tools that supersede older manual patterns. Prefer them when available in the session:

- **Workflow tool** — deterministic multi-agent orchestration (pipelines, fan-out, adversarial verify, budget loops). LOCAL subagents — token cost only, no cloud billing. Use for backlog drains, audits, migrations, exhaustive reviews — anywhere `/parallel-phases` or manual `Agent()` fan-out would need scripted control flow. Requires user opt-in ("use a workflow" / "ultracode") unless a skill mandates it. Analysis stages MUST set read-only `agentType` per agent-routing.md. Workflow slots INSIDE composite phases — the composite contract still owns phases + reconciliation; Workflow never replaces a composite.
- **Monitor tool** — stream background events (logs, CI, dev servers) into the conversation and react live. Local, free. Supersedes poll-sleep loops in `ci-watch`-style work.
- **/schedule (Routines)** — cloud agents on cron/GitHub-event/API triggers (BILLED — counts toward the $25/month cloud ceiling, see ADR 2026-06-10). NEW recurring tasks only: tasks not on launchd today AND needing off-Mac execution. Never migrate existing launchd jobs. Schedule off-hours (22:00–06:00 BRT) to avoid RAG-index / parallel-agent contention.
- **/code-review ultra** — cloud multi-agent review of current branch or PR (user-triggered, BILLED — same $25/month ceiling). High-stakes diffs to main/release only; note in memory which PRs used it.
- **/fast (Fast Mode)** — Opus with faster output on Opus 4.6+ at a price premium ($10/$50 MTok vs $5/$25 standard). A speed lever, NOT a tier: use when wall-clock matters on Opus-quality work. Haiku still owns mechanical work.
- **Effort levels (Opus 4.8+)** — `xhigh` for architecture/ADR reasoning chains only; default otherwise. Complements model tiering, does not replace it.

Decision record + revisit triggers: `standards/decisions/2026-06-10-harness-native-tools-adoption.md`.
