---
name: loop
description: 'Execute iteratively — inspect → act → verify → checkpoint — until done or blocked. Use for known plans, draining queues (PRs, issues, bumps), or multi-step recipes. Each cycle: evidence → change → narrow check → artifact + state line. Stop on unrecoverable error. Pair with `ship` (merge-bound) or `handoff` (budget overrun).'
triggers:
  - loop
  - execute this plan
  - keep going safely
  - work through these
  - drain the queue
---

# loop

Default execution rhythm once the path is clear.

## The cycle

1. **Inspect** — read the smallest missing evidence (one file, one test output, one PR comment).
2. **Act** — make the smallest coherent change (one commit-worth, ≤100-line diff for safety).
3. **Verify** — run the narrowest applicable check first (lint → unit tests → integration, stop if any fails).
4. **Checkpoint** — output a one-liner: `[cycle N] <done-what> → <state>` (e.g., `[cycle 3] Merged PR #42 → 2 remain`).
5. **Repeat** — loop back to Step 1.

## Output format per cycle

**State line** (mandatory): `[cycle N] <action> → <next-state>`  
**Artifact** (mandatory): one of: git commit, PR comment, decision doc, test result (not "ready" or "looks good").  
**Instrumentation**: if N > 5 cycles and no merge/close imminent, surface progress or re-scope.

## Stop conditions (halt, do not retry)

- **Evidence shift**: task facts have changed; re-plan instead of looping.
- **Scope creep**: diff exceeds intended boundary (e.g., small fix became a refactor); re-scope or `plan`.
- **Stuck**: same error repeats ≥2 cycles without new diagnosis; surface blocker, halt, escalate.
- **Complexity jump**: work exceeds single skill's depth; invoke `plan` or `orchestrate`.
