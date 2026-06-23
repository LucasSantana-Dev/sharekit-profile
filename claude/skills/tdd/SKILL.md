---
name: tdd
description: Short alias for test-driven development. Use for red-green-refactor, tracer bullets, behavior-driven testing, or TDD workflows.
---

# Test-Driven Development (Short)

This is the quick-reference alias for **`test-driven-development`**. Use this when you want the essentials; use the full skill for comprehensive guidance, extensive examples, and rationalization handling.

## Core Rule

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

## Red-Green-Refactor Cycle

```
RED → Failing test
GREEN → Minimal code to pass
REFACTOR → Clean up (tests still green)
REPEAT
```

## Discipline: Tracer Bullets, Not Horizontal Slices

**One test → one implementation → repeat.**

Avoid "horizontal slicing" (write all tests, then all code). This produces tests coupled to implementation shape rather than behavior. **Vertical slices** (one test + one impl per cycle) keep tests responsive to what you actually learned.

## Essential Rules

- Watch every test fail before implementing
- Write minimal code — only enough to pass current test
- Don't anticipate future tests
- Never refactor while RED
- After green, refactor freely; tests catch breaks
- Tests use public interfaces, not mocks of internals

## Verification Checklist

- [ ] Test describes behavior, not implementation
- [ ] Test uses public interface only
- [ ] Watched test fail before implementing
- [ ] Code is minimal for this test
- [ ] All tests pass

## See Full Skill

For comprehensive workflows, rationalization handling, and examples, see **`test-driven-development`** or invoke `/test-driven-development`.
