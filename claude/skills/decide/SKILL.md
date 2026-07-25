---
name: decide
description: "Makes an explicit decision with documented alternatives and rationale. Composite skill — two-phase pipeline that chains research-and-decide (research options + recommendation) → adr-write (record at proportional fidelity: DECISIONS.md line by default, full ADR only behind the record gate). Stops after Phase 1 if inconclusive. Use when making architectural or tooling decisions that need both recommendation and a durable record."
user-invocable: true
auto-invoke: >-
  architectural-decisions-needing-documentation
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/decide
triggers:
  - decide
  - research and decide
  - make a decision
  - record decision
---

# Decide

Research the question → reach a recommendation → document it as an ADR.

## Auto-invocation triggers

- User asks to "decide between X and Y", "research and decide", "pick a tool/approach and document it"
- After `adr-gap` flags an undocumented decision that needs retroactive capture
- When starting a significant architectural choice (ORM, framework, deploy target, caching strategy)

## Workflow

### Phase 1 — Research and Recommend (always)

Invoke `research-and-decide` on the decision question.

Output: options evaluated, recommendation with rationale, risks, rejected alternatives.

**Proceed:** if research produces a clear recommendation.
**Stop:** if research returns "no clear winner" or "requires more constraints" → emit "Phase 1 inconclusive: [reason]. Provide additional constraints before proceeding to ADR." Wait for human input. Do NOT write an ADR for an undecided question.

### Phase 2 — Document the Decision (at proportional fidelity, if Phase 1 succeeds)

Invoke `adr-write` using Phase 1's output. adr-write applies the record gate:
full ADR only when a gate trips (public-facing repo, sprint-level undo cost,
recurring-alternative rejection, post-incident); otherwise one status-prefixed
line in the repo's `DECISIONS.md`.

Pass to adr-write: decision title, context (the question + why it matters), chosen option + rationale, consequences, and alternatives considered.

Output: ADR file at `docs/adr/YYYY-MM-DD-<slug>.md`, or one line in `DECISIONS.md`.

**Done when:** the record (ADR file or log line) is staged or committed.
**Skip if:** the same decision is already recorded (check `DECISIONS.md` and `docs/adr/` before writing) → note path in reconciliation, mark as "already documented."

## Reconciliation

```
DECIDE — <decision question>
  Phase 1 Research:  <recommendation: X | inconclusive (stopped)>
  Phase 2 ADR:       <docs/decisions/YYYY-MM-DD-slug.md | blocked | already exists>

Decision: <one-line summary>
ADR path: <path | "pending human input">
```

## Failure / Stop Conditions

- Phase 1 inconclusive → stop, do NOT write an ADR for an undecided question
- Phase 2 duplicate detection → skip creation, surface existing path
- Never write an ADR that just says "we haven't decided yet"
