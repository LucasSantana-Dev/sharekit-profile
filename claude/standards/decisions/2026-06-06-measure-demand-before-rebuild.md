# ADR 2026-06-06 — Gate user-facing rebuilds/migrations on measured demand

**Status:** Accepted
**Scope:** Global agent-OS hard rule (`config/CLAUDE.md`)
**Via:** `/research-and-decide` (critic adjudicated which lesson + form; sharpened L1+L2 → L1-only, F-extend — no flip on form)

## Context

The Lucky Guild Automation "Module Executor" migration (this session) revealed a failure mode the
existing rules did not catch. A ~4,900-LOC user-facing subsystem was put through a multi-PR
migration that: shipped the 3 easy DB-only modules first and **never built the linchpin adapter**
the hard modules + the whole payoff depend on (stalled 3/7); left a hollow web "apply" that
reported success while applying nothing (a P1); and — the root cause — **rebuilt a feature whose
actual usage was never measured, and still isn't.**

The global `CLAUDE.md` already had **"No big-bang rewrites without a prototype gate."** It did not
fire here because the migration *was* incremental. That rule gates **technical feasibility** ("can
I build the first unit without shims?") but not **demand** ("should I rebuild this — does anyone
use it?"). An incremental migration of an unmeasured user-facing feature is a big-bang *bet on
demand* even when the implementation is incremental.

## Decision

**Extend the existing prototype-gate hard rule with one clause (L1):** before committing to a full
rewrite **or a multi-step migration/rebuild of an existing user-facing feature**, *first measure
its current usage/demand* (telemetry, event counts, a query); if usage is **unknown**, instrument
it and get data before investing — do not rebuild on the assumption it's used. Then the existing
1-hour prototype gate applies as before.

Adopted as **F-extend** (a clause on the existing always-loaded rule), not a new rule, standard
doc, tripwire, or skill check — it costs ~one sentence of always-loaded context and fires at the
exact decision point (the gate already consulted before starting a migration).

## Alternatives considered

- **Also promote L2 ("build the riskiest linchpin first / walking skeleton").** Rejected as a
  separate rule: L2 is a *consequence* of honoring L1, not an independent gate — you could build a
  skeleton and still ship easy-first. Promoting it would over-generalize (and over-engineer the
  anti-overengineering rule). Deferred to a revisit trigger.
- **New standards doc `migration-discipline.md`.** Rejected: loaded on demand → shelfware; won't be
  consulted at migration-planning time, which is exactly when it must fire.
- **Memory tripwire only.** Rejected: recall-dependent; too weak to block a pre-migration decision.
- **Encode in the overengineering-audit skill.** Rejected as the *primary* form: detects
  after-the-fact, doesn't prevent at planning time (fine as a secondary echo later).
- **New separate CLAUDE.md hard rule.** Rejected: more always-loaded bloat than extending the
  adjacent rule that already covers the same family.
- **Do nothing (the 3 incident ADRs suffice).** Rejected: under-captures a generalizable gate; the
  operator explicitly wanted a systemic rule.

## Consequences

- **Positive:** closes the precise gap (feasibility-gated, not demand-gated) at ~zero context cost;
  catches the failure *before* code review; reuses an already-followed rule's decision point.
- **Negative:** one more clause in an always-loaded file; mild risk of generalizing from n=1
  (mitigated — it codifies a known principle the incident proved was not being applied, and the
  cost is one sentence).
- **Neutral:** doesn't mandate heavy telemetry — "a query / event count / 5 minutes" satisfies it.

## Revisit when

- **A migration is measured but fails because the riskiest linchpin wasn't built first** → add L2
  as a second clause ("identify + build the linchpin path first").
- **The same clause gets written into ≥3 project CLAUDE.md files** → promote to a shared standard.
- **No demand-blind-rebuild incident recurs in 6 months** → the gate is doing its job; keep it, do
  not delete.
