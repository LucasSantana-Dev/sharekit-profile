---
name: refactor-pipeline
description: "Composite: end-to-end refactor with plan, parallel 3-agent implementation, test cleanup, ADR capture, and sync. Use when: (1) scope >5 files or cross-module boundaries; (2) user says 'rewrite / redesign module / extract / consolidate'; (3) audit-deep flagged HIGH structural issue; (4) improve-codebase-architecture recommends deepening."
user-invocable: true
auto-invoke: refactor-requests-with-cross-file-scope
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/refactor-pipeline
---

# Refactor Pipeline

Orchestrates multi-phase refactors with rollback, parallel review, post-refactor
cleanup, and durable record. Chains: refactor-plan → three-man-team (parallel) →
fix-the-suite → adr-write → docs-sync.

**Composite contract:** Do not run sub-skills manually; invoke this skill once—it
chains internally. See `standards/composite-contract.md`.

## Workflow

### Phase 1 — Plan + rollback

Invoke `refactor-plan`. Output: phased sequence with rollback per phase + effort estimate.

**Done when:** All phases estimated ≤2 days cumulative.

**STOP if:** Estimate >2 days → recommend smaller sub-refactors. Halt; do not continue.

### Phase 2 — Parallel execution

Invoke `three-man-team` with plan. Launch agents in single message:
- Architect (Opus): reads codebase, refines plan against reality
- Builder (Sonnet): implements + commits per phase boundary
- Reviewer (Sonnet): validates phase against plan + runs tests

Reviewer waits for builder per phase.

**Done when:** All phases committed, reviewer approves each + tests green.

**STOP if:** Reviewer rejects 2 consecutive phases → plan needs revision. Halt; return to Phase 1.

### Phase 3 — Post-refactor test cleanup

Invoke `fix-the-suite`. Refactors leave stale tests (wrong mocks, dropped coverage, API mismatches).

**Done when:** Coverage maintained or improved; integration tests pass with new API.

**STOP if:** Coverage drops >5% and user does not accept with rationale → revert Phase 2 commits.

### Phase 4 — Capture (mandatory)

Invoke `adr-write`. Record: what, why (structural issue), alternatives, consequences, revisit trigger.

**Done when:** ADR merged into decision record. No refactor ships without rationale artifact.

### Phase 5 — Sync + ship

Invoke `docs-sync` (if standards/skills changed), then `merge-confidently` to ship through gates.

**Done when:** PR merged, downstream synced.

## Reconciliation (signal-first)

```
REFACTOR PIPELINE — <module>
Phase 1 Plan:        ✓ / ✗ BLOCKED <reason>
Phase 2 Execute:     ✓ / ✗ BLOCKED <reason>
Phase 3 Test:        ✓ / ✗ Coverage drop >5%
Phase 4 ADR:         ADR-NNNN
Phase 5 Shipped:     PR #N merged
```

## Hard rules (composite-contract.md compliance)

- Do not run sub-skills manually. Invoke this composite once; it chains internally.
- Never skip Phase 4 (ADR). No rationale = revert.
- Coverage gate (Phase 3) is mandatory. Drops >5% require explicit user acceptance.
- Each phase must complete or surface blocker as reconciliation output. Do not silently
  switch skills or skip phases.
