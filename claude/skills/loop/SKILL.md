---
name: loop
description: Default execution rhythm — inspect → act → verify → checkpoint — applied iteratively until the task is done or a blocker emerges. Use when working through a known plan, draining a queue (PRs, issues, dependency bumps), or a multi-step recipe where each step's output informs the next. Each iteration produces a concrete artifact (commit, comment, decision) and a one-line state update. Stop on first unrecoverable error. Pair with `ship` for merge-bound work and `handoff` if budget runs out.
triggers:
  - loop
  - execute this plan
  - keep going safely
  - work through these
  - drain the queue
  - keep cycling
  - run iteratively
---

# loop

## Cycle

1. Inspect the smallest missing evidence.
**Done when:** smallest gap identified, next action clear

2. Act on the smallest coherent change.
**Done when:** artifact created and narrow surface-area check passed

3. Verify with narrow checks first.
**Done when:** narrow checks pass (lint/unit test/spot-check only)

4. Checkpoint the result.
5. Repeat until done or blocked.

## Stop conditions

Stop and re-route if:
- the evidence no longer supports the current path
- the diff grows beyond the intended scope
- the same failure repeats without progress
- the work becomes multi-step enough to require `plan`
- context budget exceeds 75% → emit `handoff`, then stop the loop
- cumulative tool-result bytes >50KB without progress → summarize + drop noise before next iteration

## Stuck protocol

If the same task has been attempted >2 times without measurable progress (same failure repeating, diff not advancing), stop the loop and emit: "Stuck: [task], attempt N, last blocker: [X]." Switch to a different approach or tool. After 2 approach switches fail without progress, escalate to the user — do not keep cycling silently.

## Output (per checkpoint)

One line per completed step: verdict + artifact produced. Report only what changed or failed. Do not narrate steps that passed cleanly.

## Parallel mode

If a `Monitor` task is running (CI settle, build, long test), do NOT busy-wait. Pick up an independent priority — refactor a different file, draft a memory note, answer an open review thread — and resume the original loop when the monitor fires its event.

Rule: at most one Monitor active per loop; otherwise events collide.
