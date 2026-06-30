---
name: refactor-pipeline
description: Composite skill — safely refactor a module end-to-end with sequencing, parallel implementation, post-refactor cleanup, and rationale capture. Chains refactor-plan (phased plan + rollback) → three-man-team (architect/builder/reviewer in parallel) → fix-the-suite post-refactor → adr-write → docs-sync. Use for non-trivial refactors that need both careful sequencing and durable record.
user-invocable: true
auto-invoke: refactor-requests-with-cross-file-scope
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/refactor-pipeline
---

# Refactor Pipeline

Heavyweight workflow for refactors that touch >5 files, span modules, or change
contracts. Combines safety (rollback plan, parallel review) with durability
(post-refactor cleanup, ADR, docs sync).

## Auto-invocation triggers

- Refactor scope >5 files OR cross-module
- User mentions "rewrite", "redesign the X module", "extract", "consolidate"
- After `audit-deep` flagged a HIGH structural issue requiring refactor
- After `improve-codebase-architecture` produced a deepening recommendation

## Workflow

### Phase 1 — Plan + rollback (always)
Invoke `refactor-plan` to write:
- Pre-refactor state snapshot (file list, public API, callers)
- Phased sequence (small commits, each independently revertible)
- Validation gate per phase
- Rollback plan per phase
- Estimated effort

Stop here if scope reveals >2 days of work — break into smaller refactors.

### Phase 2 — Parallel execution (always for non-trivial scope)
Invoke `three-man-team`:
- Architect (Opus) reads codebase, refines plan against reality
- Builder (Sonnet) implements per phase, commits per phase boundary
- Reviewer (Sonnet) validates each phase against the plan + runs tests

Three agents run in parallel where possible; reviewer waits for builder per phase.

### Phase 3 — Post-refactor test cleanup (always — refactor changes test surface)
Invoke `fix-the-suite`. After a refactor:
- Old shallow tests likely now mock the new abstraction wrong
- Coverage may drop on new code paths
- Integration tests need to be updated to the new API
This phase prevents the refactor from leaving a test suite mess.

### Phase 4 — Capture (mandatory)
Invoke `adr-write`:
- What was refactored
- Why (the structural issue or improvement opportunity)
- Alternatives considered (extract vs inline vs facade)
- Consequences (perf, testability, future-flexibility tradeoffs)
- Revisit when

Without the ADR, the next person reverts your refactor because they can't tell
why it was done.

### Phase 5 — Sync + ship (always)
- `docs-sync` to mirror any standards/skills changed
- `merge-confidently` to ship the refactor through gates

## Reconciliation

```
REFACTOR PIPELINE — <module>
  Phase 1 Plan:        <plan path, N phases, M files>
  Phase 2 Execute:     <commits, three-man-team verdict>
  Phase 3 Test cleanup: tests M→N, coverage X%→Y%
  Phase 4 ADR:         ADR-NNNN
  Phase 5 Shipped:     PR #N merged, downstream sync done
```

## Outputs / Evidence

- Refactor plan with rollback per phase
- Per-phase commits + reviewer verdicts
- Post-refactor test report
- ADR
- Merge confirmation

## Failure / Stop Conditions

- Phase 1 estimate >2 days → stop, recommend smaller sub-refactors
- Phase 2 reviewer rejects 2 phases in a row → stop, plan needs revision
- Phase 3 cannot maintain coverage even with integration tests → revert refactor
  unless user explicitly accepts the coverage drop with rationale
- Never skip Phase 4 — refactors without ADRs get reverted
