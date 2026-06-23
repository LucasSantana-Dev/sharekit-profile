---
name: verify
description: Run the narrowest meaningful validation sequence before (a) merging to main, (b) tagging a release, or (c) handing off to another agent. Scoped to what changed. Outputs a pass/fail verdict + top blockers inline. Skip if no code changed (discovery-only tasks).
triggers:
  - verify
  - before merge
  - before release
  - validate for handoff
  - run checks
---

# verify

Gate-by-gate validation, fail-fast: lint → types → targeted tests → build → security (if risk present).

## Order

1. **Lint / static checks** — Done when: no violations in changed files, or violations are pre-approved.
   - Stop if: linter not found or linter invocation fails → surface error, halt.
2. **Type checks** (where applicable) — Done when: no type errors in changed code.
   - Stop if: type checker not found, or prior lint gate failed → surface and halt.
3. **Targeted tests** — Done when: all tests covering changed code pass.
   - Stop if: test suite not found, or prior gates failed → surface and halt.
4. **Broader tests** (if risk warrants) — Done when: full suite passes, or full suite runs with no new failures.
   - Stop if: any test fails and severity is P0/P1 → surface failure, halt. If P2/P3, list and continue.
5. **Build / package check** (if relevant) — Done when: build succeeds without errors.
   - Stop if: build fails → surface error, halt.
6. **Security checks** (if dependencies or config changed) — Done when: no high-severity vulnerabilities, or all known vulns have mitigation.
   - Stop if: high-severity unmitigated vulns found → surface, halt.

## Output

**Verdict first:** PASS or FAIL (single word).

**Top 3 blockers inline** (if FAIL). If >3 failures, append "X more — run full suite for details."

**Example:**
```
PASS
All gates green: lint (0), types (0), tests (42/42), build (ok).
```

```
FAIL
Blockers:
1. [lint] Line 42: unused variable $x — fix or suppress.
2. [tests] integration/api.test.ts L18: timeout (flaky?)
3. [build] dist/ missing — run build first.
2 more failures in security scan — ask for full list.
```

## Cross-link

- Standards: See `standards/testing.md` for test strategy; `standards/verify-before-done.md` for gate details.
- Auto-chain: After `/verify` PASS, invoke `/pr-merge-readiness` before pushing to main.

## RAG

N/A (procedural, not discovery-based).
