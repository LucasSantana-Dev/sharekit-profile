---
name: orchestrate
description: Coordinate multi-step, multi-repo, or multi-phase work spanning different skills, worktrees, agents — orchestrate when one skill isn't enough (plan + parallel implementation + CI verification + ship), cross-repo migrations (≥3 repos), or multi-workstream projects. Sequences or parallelizes phases, maintains single source of truth for state, surfaces blockers at convergence points. Also sync-memories between phases, gate irreversible actions, decide serial vs. parallel vs. worktree-split execution.
triggers:
  - orchestrate
  - coordinate this
  - run a multi-step workflow
  - multi-repo delivery
metadata:
  tier: execution-layer (Sonnet)
---

# orchestrate

## Workflow

1. **Scope & plan** — Capture active repo, branch, worktree state. Read `.claude/plans/` or invoke `/plan` if one doesn't exist. Done when: decision rule (serial/parallel/worktree-split) matches ≥2 independent phases or repos.

2. **Dispatch work** — For ≥2 independent units (repos, agents, phases), dispatch in a single Agent tool call with worktrees per unit (see standards/workflow.md §parallel-execution-mandatory). Assign owner workflow to each workstream. Done when: all agents launched and initial task files or handoffs written.

3. **Monitor & gate** — Track convergence point. Before any irreversible action (merge, deploy, force-push), surface state + verdict. Check for blockers: missing test results, review comments from humans, CI failures. Done when: all workstreams reached convergence criteria OR blocker surfaced + explicit halt.

4. **Sync & handoff** — Write convergence state to `.claude/tasks/` or handoff file. If session ends mid-flow, snapshot phase, active workstreams, blocker (if any), next action. Done when: durable checkpoint written and read-back verified.

## Stop/Failure Conditions

- **No convergence plan** — if phases cannot merge cleanly (conflicting changes, no clear gate), surface blocker, halt before merge.
- **External HD unmounted** — if RAG/handoff lookup fails (mount check), fall back to plan file + inline state, log degradation.
- **Human review blocker** — if review comments exist on any open PR from a human author, halt before auto-merge (CLAUDE.md hard-rule).

## Cross-links

- Parallel execution rule: standards/workflow.md §parallel-execution-mandatory (≥2 independent units → single Agent block with worktrees).
- Agent-dispatcher boundary: standards/agent-routing.md (orchestrator drives phase calls; doesn't implement logic-bearing changes inline).
- Irreversible gate pattern: standards/workflow.md §idempotency (state-check before mutation; skip if already done).
- Composite skill reference: if intent matches a composite (plan + implement + test + ship), invoke the composite instead of running phases manually (standards/skill-auto-invoke.md).

## Output

Signal-first:
- **Verdict:** serial/parallel/worktree-split + convergence rule + go/no-go to next phase.
- **State:** active scope, workstreams (with owner skill), phase, next milestone.
- **Blocker (if any):** explicit halt + recommended recovery (retry, escalate, pivot).

Then: workstream tasks (in `.claude/tasks/`) + handoff snapshot if session pauses.
