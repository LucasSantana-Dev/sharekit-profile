# Phase 0 — Goal Characterization

Before designing anything, nail down what the loop is actually trying to do.

## Interview the user

Ask all five questions at once, not one at a time:

1. **What is the goal?** One sentence — what should the loop accomplish when it runs successfully?
2. **What does "done" look like?** What is the concrete pass/fail criterion that tells the loop to stop?
3. **What triggers the loop?** Manually, on a schedule, on an event (PR opened, file changed, ticket created)?
4. **How often / how long?** Daily? Per-commit? Until all tests pass?
5. **What is the cost tolerance?** Rough expectation — quick (< 50K tokens), medium (50K–500K), or heavy (500K+)?

## Goal Card template

Synthesize answers into a Goal Card using this exact format:

```
GOAL: <one-sentence goal>
DONE WHEN: <concrete pass/fail criterion>
TRIGGER: <what starts the loop>
CADENCE: <how often / duration>
COST TIER: quick | medium | heavy
```

Save as `goal-card.md`.

## Validation & approval

**Stop if:** Goal Card is vague, empty, or missing any of the 5 fields.
Surface: `BLOCKED: Goal Card incomplete. Missing: [field]. Next: fill in and resubmit.`

**STOP — present the Goal Card to the user and wait for confirmation before proceeding to Phase 1.** A vague or wrong goal produces a useless loop. If the user says "looks good" or similar, continue. If they correct it, update and present again.

**Done when:** Goal Card confirmed by user (all 5 fields present, user approved).
