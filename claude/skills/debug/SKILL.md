---
name: debug
description: Systematic root-cause analysis for bugs, errors, and unexpected behavior
triggers:
  - debug this
  - why is this failing
  - root cause
  - investigate
  - ultradebug
---

# Debug

Systematic debugging in 4 phases. Don't guess — trace. Find root cause before attempting any fix.

## Phase 1 — Investigation

1. **Reproduce** — get a minimal, reliable reproduction. If unreproducible, gather more data before changing code.
2. **Locate** — find the exact file, line, call path, and component boundary where it breaks.
3. **Inspect recent change** — check diffs, dependency/config/env changes, and CI/runtime differences before forming fixes. For deep call stacks, use the backward-trace technique in [references/root-cause-tracing.md](references/root-cause-tracing.md).

## Phase 2 — Pattern Analysis

4. **Compare** — find similar working code and list every meaningful difference between working and broken paths.

## Phase 3 — Hypothesis & Testing

5. **Hypothesize** — list 2-3 competing explanations, each as "I think X because Y."
6. **Evidence** — for each hypothesis, define the fastest observation that would confirm or rule it out.
7. **Test** — test one variable at a time; instrument boundary inputs/outputs when evidence is thin. For polling vs. arbitrary timeouts, see [references/condition-based-waiting.md](references/condition-based-waiting.md).

## Phase 4 — Implementation

8. **Fix** — create or identify the smallest failing check, then change exactly what the evidence points to. No bundled improvements. For validation at multiple layers once root cause is known, see [references/defense-in-depth.md](references/defense-in-depth.md).
9. **Verify** — confirm the fix resolves the issue and does not break adjacent tests/gates.

## Rules

- Never change code before you know the root cause.
- Read the actual error message — stack traces, line numbers, and codes often contain the answer.
- Check assumptions: is the value what you think it is? Add a log or probe.
- Distinguish "symptom" from "cause" — fix the cause.
- Trace data backward until you find where the bad value or state first appears.
- In multi-layer systems, verify what enters and exits every boundary (CI → build → sign, API → DB, client → server).
- If stuck after 3 hypotheses, add instrumentation before guessing more.
- If ≥2 fixes already failed, return to Phase 1 (investigation), not Phase 4; do not try "one more quick fix."
- If ≥3 fixes failed, question the architecture or original assumption, not just the next patch.

## Red flags — stop and go back to investigation

- "Quick fix now, investigate later."
- "Just try X and see if it works."
- Multiple code changes before one verification run.
- Skipping a failing test or relying only on manual verification.
- Each fix reveals a new failure somewhere else.
- A working pattern exists but the broken path adapts it differently without evidence.

## Output

```text
Root cause: <one sentence>
Location:   <file>:<line>
Fix:        <what to change and why>
```
