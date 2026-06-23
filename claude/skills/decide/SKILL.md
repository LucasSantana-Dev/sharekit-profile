---
name: decide
description: Composite skill — two-phase decision pipeline. Chains research-and-decide (research options + recommendation + critique) → adr-write (document the decision). Stops after Phase 1 if research is inconclusive and needs human input. Use when making an architectural or tooling decision that needs both a recommendation and a durable record. Triggers: pick between X and Y and record, research and decide before building, choose a tool/pattern and document it, evaluate options with critic challenge.
user-invocable: true
auto-invoke: architectural-decisions-needing-documentation
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/decide
---

# Decide

Research options → reach a recommendation → document it as an ADR.

A three-part workflow: research candidates, challenge the recommendation with critic review, and capture the decision durably. Ensures decisions are defensible and revisitable.

## Auto-invocation triggers

- User asks to "decide between X and Y", "research and decide", "pick a tool/approach and document it"
- After `adr-gap` flags an undocumented decision that needs retroactive capture
- When starting a significant architectural choice (ORM, framework, deploy target, caching strategy)

## Workflow

### Phase 1 — Research and Recommend (always)

Invoke `research-and-decide` on the decision question.

This phases chains internally: RAG pre-check (have we decided this before?) → research candidates → critic challenge → adoption plan → ADR template prep. See `research-and-decide/SKILL.md` for full orchestration.

**Mount guard** (before RAG queries): `mount | grep -q "~"` — if unmounted, state plainly and continue with offline research; RAG pre-check is optional, not blocking.

**Completion criteria:** research surfaces ≥1 option with explicit tradeoff vs. leading choice; critic produces final verdict + claims-to-verify list; adoption plan (if decision made) names pilot scope + rollback path.

**Proceed:** if research produces a clear recommendation (recommendation ≠ "needs more constraints").
**Stop:** if research returns "no clear winner", "requires more constraints", or critic flips the leading option back to prior state → emit `Phase 1 inconclusive: [reason]. Provide additional constraints before proceeding to ADR.` Wait for human input. Do NOT write an ADR for an undecided question.

### Phase 2 — Document the Decision (always, if Phase 1 succeeds)

Invoke `adr-write` using Phase 1's output.

Pass to adr-write: decision title, context (the question + why it matters), chosen option + rationale, consequences, alternatives considered, and revisit-when triggers.

See `adr-write/SKILL.md` §3–5 for template, directory search, ADR numbering, and supersession handling.

**Completion criteria:** ADR file created with all sections (context, decision, alternatives, consequences, revisit-when); superseded ADRs marked if applicable; files staged but not auto-committed.

**Skip if:** An ADR for the same decision already exists (check conventional ADR directories before writing) → note path in reconciliation, mark as "already documented"; do not create a duplicate.

**Done when:** ADR is staged (or committed), and reconciliation block is ready.

## Reconciliation

Always output this block, even on stop/failure:

```
DECIDE — <decision question>
  Phase 1 Research:  <recommendation X | inconclusive (stopped)>
                     Reason: <constraint needed | critic flipped leading option | no alternatives surfaced>
  Phase 2 ADR:       <docs/adr/NNNN-slug.md | skipped (inconclusive) | already exists at <path>>

Decision: <one-line summary | pending human input>
ADR path: <path | "N/A — Phase 1 blocked">
Next: <what to do next — provide constraints, re-run research, or proceed to Phase 2>
```

## Failure / Stop Conditions

**Phase 1 stop / hold (explicit):**
- Research returns no clear winner → emit "Phase 1 inconclusive", halt, await human input
- Critic flips the leading option and no decision emerges → loop with new dimension, do not proceed to Phase 2
- Fewer than 1 alternative considered → push back ("if there's no alternative, this isn't a decision worth recording")

**Phase 2 stop / hold (explicit):**
- Duplicate ADR exists for same decision → surface existing path, skip creation, mark in reconciliation

**Never:**
- Write an ADR that just says "we haven't decided yet"
- Auto-commit ADR; stage it and await user confirmation
- Proceed to Phase 2 without a clear recommendation from Phase 1
