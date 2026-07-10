---
name: orchestrate
description: Coordinate multi-agent teams, multi-step or multi-repo work across plans, skills, worktrees, and parallel investigations. Use when the task is large enough to benefit from parallel work, independent workstreams, and one lead agent owning synthesis.
triggers:
  - orchestrate
  - coordinate this
  - run a multi-step workflow
  - agent teams
argument-hint: '[serial|parallel|worktree-split]'
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/orchestrate
---

# orchestrate

Use for larger delivery flows and multi-agent coordination.

## Use When

- The task is large enough that parallel work will save time or add confidence.
- Independent workstreams can be defined with clear inputs, outputs, and ownership.
- One lead agent can own synthesis, integration, and final verification.
- Work spans multiple repos, skill chains, or requires worktree separation.

## Do Not Use When

- The task is small, tightly coupled, or faster to complete in one session.
- Multiple agents would fight over the same files or the same mutable context.
- The user wants one narrow implementation rather than orchestration.

## Core Responsibilities

- Decide whether work should be serial, parallel, or worktree-split
- Choose the controlling plan
- Keep one source of truth for current state
- Ensure each branch of work converges cleanly
- Plan and run multi-agent work without losing integration quality

## Inputs / Prereqs

- The goal, success criteria, and integration owner.
- Candidate workstreams and the dependencies between them.
- The quality gates or review checkpoints that must run after synthesis.
- References on team topologies, coordination patterns, or example team boards (if available).

## Workflow

1. Decide whether parallelism buys time, confidence, or separation of concerns.
   - Done when: serial/parallel/worktree-split decision is recorded and communicated to team.

2. Split the work into independent tracks with an owner, expected output, and handoff condition.
   - Done when: each track has clear input, output, and ownership + dependencies mapped.

3. Pick a lead agent to maintain the task board, resolve blockers, and synthesize results.
   - Done when: lead agent identified and briefed on integration responsibilities.

4. Give each agent a bounded prompt with files, constraints, and stop conditions.
   - Done when: each agent has received a scoped brief + stop conditions + file permissions.

5. Run sync points only at dependency boundaries, not continuously.
   - Done when: sync schedule defined and agents notified of sync times + escalation paths.

6. Recombine the work, rerun required validation, and report the integrated outcome.
   - Done when: all branches converged, validation passed, and integrated output delivered.

## Output

**Verdict:** Orchestration plan ready (serial, parallel, or worktree-split) with integration ownership confirmed.

**Top 3 state items:**
- Active scope + workstreams with named owners
- Lead agent integration role + convergence point
- Sync schedule + escalation paths + exit criteria

**Complete state:**
- workstreams and owners
- owner workflow for each stream
- active scope
- convergence point
- exit criteria
- integration lead role
- sync or escalation points

## Dispatcher ≠ executor boundary

This skill coordinates; sub-agents implement. If, while orchestrating, you find yourself writing logic (adding conditions, changing data flow, modifying retry behavior) — stop. Surface the decision as a blocker in the reconciliation output. Do not silently implement. Trivial inline edits (string constants, log labels, comment fixes) are allowed in orchestration scaffolding — log them as "inline edit — not logic-bearing."

## Failure / Stop Conditions

- Stop if the task cannot be decomposed without heavy coordination overhead.
- Stop if no agent can own final integration and verification.
- Do not use parallel agents as a substitute for a missing implementation plan.
- Stop if you are about to implement logic in the orchestrator itself (see boundary above).

## See also

- `standards/prompting-discipline.md` — 4-block Goal/Method/Constraints/Validation structure for subagent briefs (step 4)
