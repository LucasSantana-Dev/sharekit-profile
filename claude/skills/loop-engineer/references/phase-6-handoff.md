# Phase 6 — Handoff and Reconciliation Template

1. List all 6 output files with their paths
2. Show the user exactly how to invoke the loop
3. If an automation trigger was designed, include the exact config to install (launchd plist XML, cron entry, GitHub Actions YAML, etc.)

## Reconciliation template

Write a reconciliation block template that the loop outputs on every run:

```
LOOP RUN — <loop-name> @ <timestamp>
  Trigger:      <what started this run>
  Goal:         <one-line goal>
  Cycle:        <N iterations run>
  Discover:     <what was found> [OK] | [WARN] | [FAIL]
  Plan:         <what was planned> [OK] | [WARN] | [FAIL]
  Execute:      <what was done> [OK] | [WARN] | [FAIL]
  Verify:       <pass/fail + criterion> [OK] | [FAIL]
  Iterate:      <N retries, last error if any> [OK] | [WARN] | (skipped)
  Outcome:      PASSED | FAILED | ESCALATED TO HUMAN
  Memory:       <what was saved for next run>
  Next trigger: <when this loop will run again>
```

Save as `reconciliation-template.md`.

**Done when:** reconciliation template created AND all 6 output files listed with paths.
