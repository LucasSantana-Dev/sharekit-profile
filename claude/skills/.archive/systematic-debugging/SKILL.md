---
name: systematic-debugging
description: Use when encountering bugs, test failures, or unexpected behavior
  before attempting fixes. Finds root cause instead of guessing.
triggers:
  - debug this
  - find root cause
  - why is this broken
  - test failure investigation
---

# Systematic Debugging

Find root cause before fixing. No exceptions.

## When to Use

- Test failures, prod bugs, unexpected behavior
- Build breaks, integration issues, performance problems
- Under time pressure (systematic is faster than guess-and-check thrashing)
- "Just one quick fix" tempting you (red flag: stop, debug first)
- After ≥2 failed fix attempts (return to phase 1, not phase 4)

## The Four Phases

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read errors carefully** — stack traces, line numbers, exact error codes. Error message often contains the solution.

2. **Reproduce consistently** — trigger it reliably. If unreproducible, gather more data first.

3. **Check recent changes** — git diff, new deps, config changes, environment differences.

4. **Gather evidence in multi-layer systems** — for each component boundary (CI → build → sign, API → DB), log what enters, what exits, verify propagation. Show WHERE it breaks.

5. **Trace data flow** — where does bad value originate? What called it with bad data? Keep tracing up. See `root-cause-tracing.md` for the full backward-trace technique.

### Phase 2: Pattern Analysis

1. Find similar working code in the codebase.
2. Compare working vs broken — list every difference.
3. Understand dependencies — what components, config, assumptions does it need?

### Phase 3: Hypothesis and Testing

1. Form one specific hypothesis: "I think X is the root cause because Y"
2. Test minimally — smallest possible change, one variable at a time.
3. Verify. Worked? → Phase 4. Didn't? → form new hypothesis.

### Phase 4: Implementation

1. Create failing test case reproducing the issue.
2. Implement single fix addressing root cause. No bundled improvements.
3. Verify fix. Test passes? No other tests broken?
4. **If ≥3 fixes failed:** STOP. Question the architecture, not the fix.

## Red Flags — STOP and Return to Phase 1

- "Quick fix for now, investigate later"
- "Just try X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "Pattern says X but I'll adapt differently"
- "One more fix attempt" (when already tried 2+)
- Each fix reveals new problem in different place

**If 3+ fixes failed:** Question fundamentals, not symptoms.

## Support & References

- **`root-cause-tracing.md`** — backward-trace technique for deep call stacks
- **`defense-in-depth.md`** — validation at multiple layers after root cause identified
- **`condition-based-waiting.md`** — condition polling vs arbitrary timeouts

Related: `/test-driven-development` (create failing test in Phase 4.1)
