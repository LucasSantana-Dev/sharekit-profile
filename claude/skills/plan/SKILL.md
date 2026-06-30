---
name: plan
description: Build a compact, validation-gated implementation plan for multi-step, risky, or ambiguous work — when phases need explicit checkpoints, the change touches multiple files/services, or the user wants alignment before execution. Output goes to `.claude/plans/<topic>.md` (or `.agents/plans/`) with goal, in/out-of-scope, phased steps, validation per phase, and replanning triggers. Skip for trivial fixes, bug investigations (use `tracer`), or open-ended exploration (use `explore`).
triggers:
  - create a plan
  - plan this
  - what is the approach
  - draft a plan
  - design the rollout
  - phase this work
  - implementation strategy
---

# plan

Use planning only when it actually reduces risk.

## Steps

1. Read local guidance and active handoff.
2. Pull only the context needed for the task.
3. State goal, in-scope, and out-of-scope.
4. Break work into short phases.
5. Give each phase a validation step.
6. Write the plan to `.claude/plans/` or `.agents/plans/`.

## Rules

- Keep phases small enough to finish without drifting.
- Note what would cause replanning.
- If work is already partly done, document the current state before planning the rest.
- Prefer the provided plan template.

## Extend vs new plan

Before writing, scan `.claude/plans/` and `.agents/plans/`:

- Existing plan covers same scope AND ≤30 days old → **extend** (append phases, edit status header, keep history).
- Same scope but >30 days old → new plan; mark old as **superseded**.
- Different scope → new plan.

When extending, update the status header to reflect partial completion (e.g. "Phases 1-5 done; Phases 6-8 added 2026-05-14").

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
- Pure investigation / "where is X" → use `explore`
- Bug root-cause hunt → use `tracer`
- Open-ended ideation → use `brainstorming`

## Worked example — extend

User: "add WoL panel + tabs to dashboard."
Existing: `homepage-customization-2026-05-13.md` (5 phases, 1 day old).
Action: append Phase 6-8 to that file; do NOT create a second plan. Update header to note the extension date.
