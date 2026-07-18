# Teardown Contract

Shared by `app-teardown` (live apps) and `code-teardown` (repos). Field names are stable;
downstream skills (plan, backlog) and future sessions parse this format.

## Report skeleton

```markdown
# Teardown — <target> (<date>)

target: <url | repo>
evaluated-for: <our project>
coverage: full | partial (<what was walled/missing>)
summary: <N> findings — <A> adopt · <D> adapt · <H> already-have · <R> rejected

## ADOPT list (ranked)
1. <finding id> — <one line> · effort <S|M|L> · lands in <path/module>

## Findings

### F1 — <name> [<dimension>]
- evidence: <screenshot path | file:line | URL>
- what: <what they do, 1-3 sentences>
- why-it-works-for-them: <the constraint/context that makes it good THERE>
- rationale: [their constraint] → [applies to us? yes/no/partially, why] → [action]
- verdict: adopt | adapt | already-have | reject
- effort: S | M | L        (only for adopt/adapt)
- lands-in: <file/module/epic>   (only for adopt/adapt)
```

## Verdicts

- **adopt** — transfers as-is; constraint rationale shows our context shares theirs.
- **adapt** — the idea transfers, the implementation doesn't; state what changes and why.
- **already-have** — state-check found it in our codebase/memory; cite where.
- **reject** — good for them, wrong for us; the rationale names the diverging constraint.

## Cargo-cult gates (all mandatory before any `adopt`)

1. **Rationale present** — the three-part "[theirs] → [ours?] → [action]" chain. A finding
   without it is an observation, not a recommendation.
2. **State-check done** — graphify query (if `graphify-out/` exists) + grep + memory
   lookup. Cite the negative search, not just assert novelty.
3. **Constraint transfer** — if their design exists because of scale/legacy/pricing we do
   not share, the verdict cannot be `adopt` (adapt or reject, with the divergence named).
4. **Prior-evaluation check** — `reference_<target>_evaluated_*` memory consulted before
   the teardown started; if present and revisit condition unmet, stop.

## Memory protocol

One note per teardown: `reference_<target>_evaluated_<date>.md`
- outcome: `adopted: <ids>` | `nothing` | `partial: <ids>`
- revisit-when: <condition — e.g. "target ships v2", "our project adds billing">
- pointer to the report path.

"Evaluated → nothing" is a first-class outcome (precedent: megabrain 2026-07-12, llmwiki
2026-07-15 — both notes prevented paid re-evaluation).
