---
name: loop
description: "Detect when the agent is repeating the same action or approach without progress, then break the cycle. Identifies loop patterns: trying the same fix repeatedly, re-reading the same files, re-running the same commands, or circling between alternatives. Injects a pattern interrupt, suggests alternative approaches, and forces a different strategy. Use when the agent seems stuck in a loop, when the user says \"you're going in circles\", or when the same error recurs after 3+ attempts."
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
