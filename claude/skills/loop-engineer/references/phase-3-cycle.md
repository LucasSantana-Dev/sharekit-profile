# Phase 3 — 5-Stage Cycle Design

Map the five stages to THIS task. Each entry must be concrete — not "Execute = do the task" but "Execute = run `npm test` and capture stdout/stderr". Generic descriptions are not acceptable.

## Cycle table template

| Stage | This loop — concrete action |
|-------|-----------------------------|
| Discover | ___ |
| Plan | ___ |
| Execute | ___ |
| Verify | ___ |
| Iterate | ___ |

Also define:
- **Stop condition**: exact criterion to exit the loop successfully
- **Escape hatch**: after how many failed iterations does it escalate to human?

## Flow diagram

Write the cycle as a flow diagram:

```
[TRIGGER]
  ↓
Discover: <concrete action>
  ↓
Plan: <concrete action>
  ↓
Execute: <concrete action>
  ↓
Verify: <pass/fail check — be specific>
  ↓ fail
Iterate: <how it fixes and loops back>
  ↓ pass (or escalate after N failures)
[DONE / HANDOFF]
```

Save as `cycle.md`. Present to user and confirm before Phase 4.
