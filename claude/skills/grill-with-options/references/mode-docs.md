# Docs mode (from grill-with-docs)

Interview relentlessly about every aspect of the plan until shared understanding is reached. Walk down each branch of the design tree, resolving dependencies between decisions one by one. For each question, give your recommended answer. Ask one question at a time and wait for feedback before continuing. If the codebase can answer a question, explore it instead of asking.

Bounded options still apply per fork when the alternatives are known (use `AskUserQuestion`); otherwise use open-mode Q/GUESS shape with a recommended answer.

## Domain awareness

While exploring the codebase, look for existing documentation.

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          <- system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 <- context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily, only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

- **Challenge against the glossary.** When the user uses a term that conflicts with `CONTEXT.md`, call it out immediately and quote the definition: "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"
- **Sharpen fuzzy language.** For vague or overloaded terms, propose a precise canonical term: "You're saying 'account'. Do you mean the Customer or the User?"
- **Discuss concrete scenarios.** Invent scenarios that probe edge cases and force precision about the boundaries between concepts.
- **Cross-reference with code.** When the user states how something works, check whether the code agrees. Surface contradictions: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"
- **Update CONTEXT.md inline.** When a term is resolved, update `CONTEXT.md` right there; do not batch. Use [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md). `CONTEXT.md` is a glossary and nothing else: no implementation details, no spec, no scratch pad.
- **Do not ask what CONTEXT.md already answers.** Do not rewrite the plan.

## ADR gate (offer sparingly)

Offer an ADR only when all three are true:

1. **Hard to reverse:** the cost of changing your mind later is meaningful
2. **Surprising without context:** a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off:** genuine alternatives existed and one was picked for specific reasons

If any is missing, skip the ADR and say which criteria fail (for example a subject-line wording change is trivially reversible and unsurprising: not an ADR). Never produce a full ADR for such a decision. Format: [ADR-FORMAT.md](./ADR-FORMAT.md).

## Stop conditions

Same as options/open mode: 95% predictive test, then restate decisions and get an explicit "yes"; floor stop when the same forks keep reopening.
