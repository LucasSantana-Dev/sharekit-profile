---
name: refactor
description: 'Surgical code refactoring to improve maintainability without changing behavior. Invoke when user says "refactor this", "clean up this code", "extract functions", "this is messy", "improve maintainability", "fix code smells", "simplify this", "this function is too long", or when you see god functions, nested conditionals, duplicate logic, magic numbers, unclear naming, or dead code. Always run a discovery pass first — catalog smells before touching anything. Gradual evolution, not revolution.'
license: MIT
triggers:
  - refactor
  - clean up
  - improve maintainability
  - code smells
---

# Refactor

Improve code structure and readability without changing external behavior. Behavior is sacred; structure is up for negotiation.

## Core Principle

**Discover before you fix.** It's tempting to jump straight into the most obvious problem, but surveying the whole file first gives a better picture of what's worth fixing and in what order. It also surfaces smell dependencies (fixing X may make Y irrelevant). Never start editing until you've cataloged.

## Phase 0 — Discover

Read the target file(s). Note language. Scan for every smell present.

**Language detection:** Adapt patterns and tool suggestions to the actual language:

| Language | Smell finders | Refactor tools |
|---|---|---|
| TS / JS | ESLint, ts-prune, unimported | ts-morph, jscodeshift, ast-grep |
| Python | pylint, ruff, vulture | rope, pyupgrade, ruff --fix |
| Go | staticcheck, golangci-lint | gorename, gopls |
| Rust | clippy | cargo fix |

**Also read 2–3 similar files in the project** before proposing changes. Refactoring should feel native to the codebase — matching its naming conventions, its error-handling style, its test structure. A brilliant refactor that looks foreign is still a bad refactor.

**Catalog your findings:**
```
Smells found in auth.ts:
  [HIGH]  Nested conditionals — handleAuth() has 8 levels of nesting; every error path buried inside
  [HIGH]  Long method — 120 lines doing token parse, DB lookup, audit log, and response all in one
  [MED]   Magic numbers — status === 2 and status === 1 appear without named constants
  [LOW]   Feature envy — Order.calculateDiscount() reads deep into User internals
```

Surface the catalog in this format — **include all four parts**:

```
Smells found in <filename>:
  [HIGH] ...
  [MED]  ...
  [LOW]  ...

Tool that catches this automatically: <name> (e.g. ESLint no-unused-vars, pylint, ruff, ts-prune)

Behavior guarantee: All changes will preserve external behavior — same inputs, same outputs, same side effects.

Scope: I'll fix [highest-priority smell / the one you mentioned]. Which smells should I address this session?
```

The behavior guarantee belongs in the discovery output, not buried in later phases. Users refactoring auth handlers, payment flows, or any critical path need this assurance before they say "go."

See REFERENCE.md for smell definitions and before/after code examples.

## Phase 1 — Prepare

Before touching any code:

1. **Tests exist?** If not → write minimal characterization tests first (tests that capture *current* behavior, not ideal behavior). Refactoring without tests is flying blind — you can't know if you broke anything.
2. **Suite is green.** Run the tests. If they fail before you start, stop and surface that to the user.
3. **Capture the baseline.** Note the current git SHA or commit current state. This is your rollback point.

*Done when:* Tests green, baseline captured.

## Phase 2 — Refactor (atomic steps)

Fix one smell at a time. For each agreed smell:

1. **Name what you're extracting** — what's the new function/constant/class called? Make the name obvious.
2. **Make the change and show it** — edit the code; then show the complete refactored version (or the key before/after diff). Don't just describe what changed — show it. Users need to see the actual code to review it.
3. **Run tests** — if anything fails, the step was too big; revert and try a smaller cut.
4. **Commit** — one commit per extraction: `refactor: extract validateToken() from handleAuth()`

Repeat for each agreed smell in priority order.

**Why atomic commits matter:** Each commit is a safe rollback point. If something breaks later, you'll know exactly which extraction caused it. Code review also becomes much easier — each commit is one clear decision.

**Scope discipline:** Don't fix smells you didn't agree on with the user. If you spot a new one mid-session, note it in the Phase 4 summary for a future pass. Stay on target.

## Phase 3 — Verify

After all agreed smells are addressed:
- Full test suite green
- If user-facing code changed: manual smoke test
- No performance regressions — if any hot loops or rendering paths were touched, benchmark before/after

If tests fail: trace to the specific commit that broke them, revert that step, re-approach with a smaller extraction.

## Phase 4 — Summary

End every session with a clear picture of what changed and what remains:

```
Refactored: src/auth/handleAuth.ts

Changes made:
  ✓ Extracted validateToken(jwt) — was inline in handleAuth(), now independently testable
  ✓ Extracted lookupUser(userId) — separates DB concern from auth logic
  ✓ Replaced magic numbers with UserStatus enum (ACTIVE = 1, SUSPENDED = 2)

Deferred (next session):
  → Feature envy in Order.calculateDiscount() — User refactor should come first
  → Long audit log block — low risk to leave for now

Commits: 3 atomic
Tests: 42 pass, 0 fail
```

## Approach by target

**Function:** Extract steps into sub-functions; guard clauses instead of nesting; group parameters into objects.

**Class:** Move unrelated methods to new classes; extract interfaces; break cycles by introducing adapters.

**Module:** Ensure dependencies flow in one direction; no circular imports; clear public API via exports.

**Name:** Use domain language; be specific (`getUserByEmail` not `get`); avoid abbreviations.

**Type:** Replace string/number codes with enums; add union types for optional fields; define explicit return types.

## Smell Reference

See REFERENCE.md for the full catalog with before/after code examples:
- Long methods, duplicated code, god objects, long parameter lists, feature envy
- Magic numbers, nested conditionals, dead code, primitive obsession, inappropriate intimacy
- Strategy pattern, Chain of Responsibility, Extract Method walkthrough
- Type safety progression (untyped → fully typed)

## When NOT to Refactor

- Code that works and won't change again (the cost of refactoring outweighs the benefit)
- Critical code with no tests — add characterization tests first; that's a separate task
- Under a tight deadline — make a note, refactor after
- "Just because" — need a clear reason: testability, clarity, onboarding, performance

## See also

- `standards/naming-conventions.md` — case, boolean-prefix, and abbreviation rules to apply when renaming
