# Debugging Skills

Start with `debug` for most bugs. Escalate to `debug-deep` (composite) when the issue spans CI, Sentry, and multiple services. `adt-self-heal` for autonomous recovery in agent pipelines.

---

## /debug

Systematic root-cause analysis for bugs, errors, and unexpected behavior.

**4-Phase method:**
1. **Reproduce:** Make the bug happen reliably
2. **Isolate:** Narrow scope (file, function, condition)
3. **Investigate:** Trace code path + data flow
4. **Fix:** Minimal change that prevents bug (not workaround)

**When to use:** Any bug, test failure, or unexpected behavior

**Blocks:** Rationalization attempts (e.g., "must be a fluke")

**Output:** Root cause + fix (not band-aid)

---

## /debug-deep ⭐⭐ **Composite**

Full debugging workflow: systematic-debugging → tracer → sentry → ci-watch → incident-response.

**Phases:**
1. **Systematic debugging:** 4-phase root-cause analysis
2. **Tracing:** Competing hypotheses + evidence weighting
3. **Sentry inspection:** Production error context + stack traces
4. **CI analysis:** Failed check logs + history
5. **Incident coordination:** Triage + tracking

**When to use:** Bug spans multiple services/CI/production (complex)

**Output:** Root cause + fix + incident record

---

## /systematic-debugging

Structured root-cause analysis when encountering bugs, test failures, or unexpected behavior.

**Discipline:**
- Enforce step-by-step investigation
- Block assumptions + rationalization
- Track evidence for/against each hypothesis
- Measure progress (are we getting closer?)

**Phases:**
1. State the expected behavior
2. State the actual behavior
3. Propose competing hypotheses
4. Design test for each hypothesis
5. Execute tests, weight evidence
6. Converge on root cause

**When to use:** Bug is not obvious; multiple hypotheses possible

**Output:** Root cause + confidence level

---

## /adt-self-heal

Autonomous error recovery — detect failures, diagnose root cause, apply fixes, and resume without stopping.

**Workflow:**
1. Detect failure (exception, exit code, assertion)
2. Diagnose root cause
3. Apply fix (if reversible + low-risk)
4. Resume work
5. Log recovery + lessons

**When to use:** In agent pipelines; during batch operations; when resumable

**Output:** Self-recovered work + recovery log

---

## /adt-build-fix

Local build-error triage. Detects common compile errors and suggests fixes.

**Handles:**
- Missing dependencies (suggest `npm install`)
- Type errors (suggest fix or explain)
- Config errors (tsconfig, webpack, etc.)
- Environment issues (Node version, env vars)

**When to use:** Build fails locally

**Output:** Error diagnosis + suggested fix

---

**Last updated:** 2026-06-25
