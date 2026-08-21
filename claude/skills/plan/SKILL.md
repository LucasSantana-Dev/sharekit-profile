---
name: plan
description: Create a structured implementation plan before starting complex work. Breaks work into small phases, each with exact file paths, a runnable verification command, a checkable done-condition, and replanning triggers, plus explicit goal and in/out-of-scope boundaries. Use when the user says "plan this", "create a plan", "break this down", "phase this work", or when a task has multiple phases or unknowns. Also use when the agent needs to think before acting on complex tasks.
triggers:
  - create a plan
  - plan this
  - what is the approach
  - draft a plan
  - design the rollout
  - phase this work
  - implementation strategy
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/plan
---

# plan

Use planning only when it actually reduces risk.

## Steps

1. Read local guidance and active handoff.
2. Pull only the context needed for the task.
3. State goal, in-scope, and out-of-scope.
4. Break work into short phases.
5. Give each phase exact file paths (**Files Touched**) and a runnable **Verify** command — agents execute paths and commands, not prose.
6. Write the plan to `.claude/plans/` or `.agents/plans/`.

## Rules

- Keep phases small enough to finish without drifting.
- Note what would cause replanning.
- If work is already partly done, document the current state before planning the rest.
- Prefer the provided plan template (`references/plan-template.md`).
- Don't over-specify: too much detail buries priorities. File paths, scope, verification — then stop.

## Extend vs new plan

Before writing, scan `.claude/plans/` and `.agents/plans/`:

- Existing plan covers same scope AND ≤30 days old → **extend** (append phases, edit status header, keep history).
- Same scope but >30 days old → new plan; mark old as **superseded**.
- Different scope → new plan.

When extending, update the status header to reflect partial completion (e.g. "Phases 1-5 done; Phases 6-8 added 2026-05-14").

## Parallel execution

If the plan's tasks will fan out to ≥2 parallel agents, the executor is `/parallel-phases` and it ingests a task-level schema (`### T1` blocks with specialist/model/scope_in/scope_out/depends_on/acceptance — see `parallel-phases/references/plan-format.md`). Write sequential plans with this skill's template; write fan-out plans directly in that schema.

## No big-bang rewrite gate

When the task scope is a rewrite (replacing an existing module, service, or significant subsystem), add an explicit Phase 0 before all implementation phases:

**Phase 0 — Prototype gate (1 hour max)**
- Implement the first incremental unit only
- Validate: does it expose >3 friction points? Does it require >2 temporary shims?
- If yes → stop, invoke `/research-and-decide` to evaluate whether big-bang is justified
- If no → continue with incremental plan

Do not skip Phase 0 for perceived urgency. The gate exists because "incremental is feasible" is an assumption, not a fact.

## Skip plan if

- ≤2 files touched AND edit is obvious from the request → just do it, no plan
- Pure investigation / "where is X" → dispatch the `Explore` agent
- Bug root-cause hunt → dispatch the `tracer` agent
- Open-ended ideation → use `brainstorming`
- Plan needs visual review (diagrams, mockups, annotated code) → use `/visual-plan`
- Strategic/product planning needing a user interview → dispatch the `planner` agent

## Worked example — extend

User: "add WoL panel + tabs to dashboard."
Existing: `homepage-customization-2026-05-13.md` (5 phases, 1 day old).
Action: append Phase 6-8 to that file; do NOT create a second plan. Update header to note the extension date.
