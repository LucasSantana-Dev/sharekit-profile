# Planning & Execution Skills

Use these to scope work before touching code and to choose the right execution shape. Archived broad wrappers such as `route`, `scope-and-execute`, and `feature-from-zero` are represented by active skills below.

---

## /plan

Build a compact, validation-gated implementation plan for multi-step, risky, or ambiguous work.

**When to use:** Non-trivial implementation, high risk, multiple viable approaches, or explicit plan request.

**Output:** Problem, current state, proposed changes, validation criteria, and orchestration strategy when useful.

---

## /scope-it

Disambiguate intent, constraints, success criteria, and out-of-scope work before implementation.

**When to use:** The request could mean multiple things, or the smallest safe slice is unclear.

**Output:** Narrowed scope and recommended active entry point.

---

## /next-priority

Decide the highest-value safe thing to do right now in the active repo or workspace.

**Considers:** blockers, open PRs, failing checks, customer impact, and effort.

---

## /loop

Default execution rhythm: inspect → act → verify → checkpoint.

**When to use:** Single-threaded incremental work.

---

## /dispatch

Split cleanly separable investigation work into parallel tracks, then reconcile results.

**When to use:** Two or more independent read-only or low-conflict investigations.

---

## /orchestrate

Coordinate multi-agent, multi-step, or multi-repo work across plans, skills, worktrees, and validation barriers.

**When to use:** Work spans multiple repos, multiple phases, parallel implementation lanes, or complex handoffs.

---

## /three-man-team

High-complexity Architect → Builder → Reviewer pattern for work that benefits from lane separation.

**When to use:** Architecture-sensitive changes, broad refactors, or implementation that needs independent review.

---

## /add

Add one focused feature, test, config, doc, or automation safely with scope and validation.

---

## Active greenfield feature pattern

For new features, compose active skills rather than restoring archived wrappers:

1. `/scope-it` to define MVP and constraints.
2. `/plan` for non-trivial design and validation.
3. `/frontend-design`, `/domain-modeling`, or `/codebase-design` as needed.
4. `/tdd` or `/test-driven-development` for test-first implementation.
5. `/quality-gates` and `/ship` when ready.
6. `/knowledge-loop` to capture decisions and handoff.

**Last updated:** 2026-07-01
