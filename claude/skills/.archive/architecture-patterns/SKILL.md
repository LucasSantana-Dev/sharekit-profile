---
name: architecture-patterns
description: Choose and apply backend architecture patterns such as Clean Architecture,
  Hexagonal Architecture, and Domain-Driven Design. Use when designing system boundaries,
  refactoring toward better separation, or evaluating architectural tradeoffs.
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/architecture-patterns
---









# Architecture Patterns

Use this skill to select and explain the right architectural pattern for a backend or service boundary.

## Use When

- A new system or subsystem needs a durable architecture direction.
- A codebase is too coupled and needs clearer boundaries.
- The team must compare Clean Architecture, Hexagonal Architecture, or DDD tradeoffs.

## Do Not Use When

- The task is a narrow implementation detail inside an already-set architecture.
- The main problem is language, framework, or testing mechanics rather than system structure.

## Inputs / Prereqs

- The system boundary, current pain points, and the team or delivery constraints.
- Whether the choice is about pattern selection, Clean Architecture, Hexagonal, or DDD detail.
- Load only the relevant reference for the current architectural decision.

## Workflow

1. Diagnose the actual architectural pain: coupling, testability, domain complexity, or integration churn.
2. Choose the smallest pattern that solves that pain without over-architecting.
3. Pull the relevant reference for selection guidance or one of the major patterns.
4. Report the pattern choice, tradeoffs, and the boundaries that must remain explicit.

## Outputs / Evidence

- A concrete architecture recommendation or comparison.
- The reasons that recommendation fits the current system and team constraints.
- The main boundary rules, tradeoffs, and migration cautions.

## Failure / Stop Conditions

- Do not prescribe a heavyweight pattern when the system complexity does not justify it.
- Do not discuss architecture in the abstract without tying it to the actual change pressure.
- Do not hide migration cost, boundary friction, or team skill constraints.

## Load These Resources

- `references/pattern-selection.md`
- `references/clean-architecture.md`
- `references/hexagonal-architecture.md`
- `references/domain-driven-design.md`

## Memory Hooks

- Read memory when the workspace already has architectural conventions or prior boundary decisions.
- Write memory only if the session establishes a durable architecture standard or migration rule.
