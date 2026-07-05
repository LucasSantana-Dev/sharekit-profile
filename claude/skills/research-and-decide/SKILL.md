---
name: research-and-decide
description: Composite skill — research a question, challenge the conclusion, plan adoption, and capture the decision. Chains adt-research or brainstorming (explore) → critic agent (challenge) → plan (sequence) → adr-write (record). Use when evaluating a library / pattern / architecture choice — forces the research-to-ADR pairing that usually slips.
user-invocable: true
auto-invoke: choice-questions + library-evaluations
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/research-and-decide
---

# Research and Decide

You make decisions all day; most never get captured. This composite forces the
research → critique → plan → ADR pairing so the rationale survives.

## Auto-invocation triggers

- User asks "should we use X or Y", "is X worth adopting", "what's the right pattern for"
- Comparing libraries, frameworks, services, or architecture options
- Evaluating a vendor / API / SaaS adoption
- Spec-driven design questions before implementation

## Workflow

### Phase 1 — Research (always)
- Open-ended exploration: invoke `brainstorming` to surface options and constraints
- Specific tech evaluation: invoke `adt-research` for web + docs + repo evidence
- Output: 5-10 candidates with one-line tradeoff per candidate

### Phase 2 — Challenge (always — this is what makes the decision durable)
Invoke `critic` agent (Opus, multi-perspective review) on the leading 1-2 options:
- Cost over 12 months
- Migration friction
- Lock-in risk
- Failure modes specific to your stack
- What changes the answer (revisit triggers)

Apply the `decision-discipline.md` standard's 5-step scaffold
(CLAIM → EXTRACT → DOUBT → RECONCILE → STOP) on the leading artifact —
critic invocations should pass ARTIFACT + CONTRACT only, never the CLAIM
or your reasoning (that biases the reviewer toward agreement).

If `critic` flips the leading option → loop back to Phase 1 with the new dimension
to evaluate.

### Phase 3 — Plan adoption (only if a decision is made)
Invoke `plan` to sequence:
- Pilot scope (1 module or feature)
- Success criteria for the pilot
- Rollback plan if the pilot fails
- Full-rollout sequencing

Skip Phase 3 if the decision is "no change" or "defer".

### Phase 4 — Record (always — even no-decision is a decision)
Invoke `adr-write` with the full template:
- Context (what forced the choice)
- Decision (or "deferred", with the trigger that would re-open it)
- Alternatives considered (the Phase 1 candidates with rejection reasons)
- Consequences (positive, negative, neutral)
- Revisit when (the conditions that change the answer)

### Phase 5 — Capture for future search
Invoke `knowledge-loop` to ensure the ADR is indexed and surfaceable from RAG. The
ADR is worthless if you can't find it 6 months later.

## Reconciliation

```
RESEARCH AND DECIDE — <question>
  Phase 1 Research:      N candidates explored, top 2: <X> vs <Y> ✅ DONE
  Phase 2 Critique:      <flipped winner Y/N>, key risks identified ✅ DONE
  Phase 3 Plan:          <pilot path / deferred / no-change> ✅ DONE
  Phase 4 ADR:           ADR-NNNN <title> ✅ DONE
  Phase 5 Indexed:       RAG chunks added ✅ DONE
  Snapshot:              (none — decision is recorded in ADR)
  Open watch:            (none) | <e.g. "pilot <option> in <scope>, revisit when <trigger>">
```

## Outputs / Evidence

- Research summary (Phase 1)
- Critic assessment (Phase 2)
- Adoption plan if applicable (Phase 3)
- ADR file (Phase 4)
- RAG indexing confirmation (Phase 5)

## Failure / Stop Conditions

- Phase 2 critic identifies a blocker the research missed → loop, do not push the
  weaker option through
- User cannot articulate at least one alternative considered → push back
  ("if there was no alternative, this isn't a decision worth recording")
- Refuse to write Phase 4 ADR without a revisit-when condition; permanent
  decisions tend to outlive their value

Snapshot:
Open watch:            (none)
