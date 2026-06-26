---
name: resume
description: Rehydrate the current task from handoffs, plans, tasks, memory notes, and git state.
triggers:
  - resume
  - continue
  - what was I doing
---

# resume

Recover state before doing new work.

## Read order

1. `~/.claude/handoffs/<project>/latest.md`
2. `~/.claude/handoffs/latest.md`
3. newest plan in `.claude/plans/` or `.agents/plans/`
4. `.agents/memory/in-progress.md`
5. current git branch, status, and open PRs

## Post-incident check

After loading the handoff, scan for OPEN incident flags (P0/P1 failures). If present, surface before anything else: a committed root-cause artifact (ADR or incident-log) is required before the next task proceeds. Do not silently skip an open incident flag and start a new task.

## Output

Return:
- active objective
- repo, branch, worktree
- what is already done
- what remains
- exact next action
- any open incident flags (if found)

## Failure / Stop Conditions

- If no handoff, plan, or git context is found → surface "no context found" and ask the user for orientation rather than guessing an objective.
- Do not invent a task when all context sources are empty.

## Pair with standards

- `standards/session-budget.md` — defines when to create checkpoints/handoffs (70%/90% context thresholds) that resume rehydrates from
