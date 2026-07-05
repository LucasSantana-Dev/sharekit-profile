---
name: add
description: Add a feature, test, config, doc, or automation safely with clear scope and validation.
triggers:
  - add
  - implement
  - introduce this
---

# add

Use when introducing new behavior.

## Steps

1. Confirm the desired contract or behavior.
2. Estimate the touch surface.
3. Implement the smallest safe version.
4. Protect existing behavior with tests or focused validation.
5. Check for docs, config, or rollout impact.

## Rules

- Prefer extension over broad rewrites.
- Name what must not regress.
- Keep the first version easy to review.

## Rewrite gate

If implementing the addition would require touching >5 files or >150 LOC or removing existing behavior, stop. Treat it as a rewrite, not an addition. Apply the no-big-bang gate: complete a prototype of the smallest incremental unit first. If the prototype exposes >3 friction points or requires >2 temporary shims, escalate to `/decide` before continuing.

## Failure / Stop Conditions

- Stop if the scope expands beyond what was asked — surface the scope creep explicitly before proceeding.
- Stop if the required behavior is undefined — name the ambiguity rather than guessing a contract.
- Do not commit or merge without at least one test covering the new behavior.

## Memory Hooks

- Read memory for prior decisions about the same feature area or similar patterns — they may constrain the implementation shape.
- Write memory only if the addition establishes a durable convention worth carrying forward.
