# Architecture & Design Decision Skills

`adr-write` after any significant technical decision. `research-and-decide` (composite) when you need to explore options before deciding. `grill-me` to stress-test your own plan before committing. `brainstorming` for open-ended exploration.

---

## /adr-write

Capture an Architecture Decision Record — what was decided, why, alternatives, when to revisit.

**Sections:**
- **Status:** Proposed / Accepted / Deprecated
- **Context:** Problem statement + constraints
- **Decision:** What was decided + why
- **Alternatives:** What else was considered + trade-offs
- **Consequences:** Expected outcomes + risks
- **Revisit when:** Conditions that would change the decision

**When to use:** After any significant technical choice (library, pattern, architecture)

**Where:** Commit to `~/.claude-env/adrs/` or `docs/adrs/`

**Output:** Durable ADR + indexed for future recall

---

## /research-and-decide ⭐⭐ **Composite**

Research → critic challenge → plan → ADR. Forces the research-to-decision pairing.

**Phases:**
1. **Research:** Deep investigation of candidates
2. **Critic:** Adversarial challenge to proposed choice
3. **Plan:** Adoption strategy if decision survives critique
4. **ADR:** Document decision + when to revisit
5. **Index:** Add to memory vault for future recall

**When to use:** Evaluating library/pattern/architecture choices with lock-in risk

**Purpose:** Prevent decisions-without-evidence

**Output:** Durable ADR + indexed decision

---

## /grill-me

Interview the user relentlessly about a plan or design until reaching shared understanding.

**Questions probe:**
- Why this approach (not alternatives)?
- What could break?
- What's the failure mode?
- How will you know if it worked?
- Who else needs to understand this?

**When to use:** Before committing to big design / architecture; stress-test your thinking

**Output:** Deeper design + shared understanding

---

## /grill-with-docs

Grilling session that challenges your plan against the existing domain model and updates documentation inline.

**Process:**
1. Read existing domain docs / ADRs / CONTEXT.md
2. Challenge proposed design against existing patterns
3. Identify conflicts or gaps
4. Update docs to reflect decisions

**When to use:** New design in existing codebase; ensure consistency with prior decisions

**Output:** Grilled design + updated domain docs

---

## /brainstorming

Facilitate collaborative idea exploration and turn rough concepts into structured proposals.

**Process:**
1. State problem + constraints
2. Generate options (no evaluation yet)
3. Evaluate options (pros/cons, trade-offs)
4. Converge on approach
5. Define next steps

**When to use:** Open-ended exploration; fuzzy requirements

**Output:** Structured proposal + next steps

---

## /api-design-principles

Master REST and GraphQL API design principles for intuitive, scalable APIs.

**REST:**
- Resource-oriented (nouns, not verbs)
- HTTP methods (GET, POST, PUT, DELETE)
- Status codes (200, 201, 400, 404, 500)
- Pagination + filtering
- Content negotiation

**GraphQL:**
- Query language (typed schema)
- Single endpoint
- Over-fetching prevention
- Under-fetching prevention
- Subscriptions for real-time

**When to use:** Designing new API; API design review

**Output:** API design principles + patterns

---

## /architecture-patterns

Choose and apply backend architecture patterns — Clean Architecture, DDD, CQRS, and more.

**Patterns:**
- **Clean Architecture:** Layered (entities, use cases, controllers, frameworks)
- **Domain-Driven Design (DDD):** Ubiquitous language, bounded contexts, value objects
- **CQRS:** Command Query Responsibility Segregation (separate read/write models)
- **Event Sourcing:** Immutable event log + state reconstruction
- **Hexagonal:** Ports + adapters, anti-corruption layers

**When to use:** Designing complex domain logic; architectural review

**Output:** Architecture pattern recommendation + implementation guide

---

## /prototype

Build a throwaway prototype to flesh out a design before committing.

**When to use:** Design is fuzzy; benefits of prototyping > time cost

**Routes to:**
- Terminal app (CLI prototype)
- Web UI (browser prototype)
- API (endpoint prototype)

**Output:** Working prototype + lessons learned

---

**Last updated:** 2026-06-25
