---
name: verify
description: Run the narrowest meaningful validation sequence before merge, release, or handoff.
triggers:
  - verify
  - run checks
  - validate this
---

# verify

Do not merge, release, or claim done without verification.

## Before running

State-check: if the most recent CI run against the same commit SHA is already fully green on all required gates, log "already verified at <SHA> — skipping" and stop. Only re-run if code has changed since that run.

## Order

1. lint or static checks
2. type checks where applicable
3. targeted tests
4. broader tests if risk warrants it
5. build/package checks if relevant
6. security checks when dependencies or config changed

## Output

Signal-first: verdict on the first line ("PASS" / "FAIL" / "PARTIAL"), then list only the gates that have signal (failures, warnings, skipped-but-required). Do not enumerate gates that passed cleanly.

```
PASS — all required gates green
  Skipped: security (no dep changes)

FAIL — 1 required gate failing
  type-check: packages/bot — 3 errors in src/foo.ts
  lint: clean
  tests: clean
```

## Failure / Stop Conditions

- If a gate fails on code unrelated to the current change, name it as pre-existing and note whether it blocks shipping.
- Do not claim "verified" if any required gate was skipped for a reason other than "not applicable."
- Do not merge on PARTIAL without explicit user acknowledgement of what was skipped.
