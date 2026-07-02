# Report Output Patterns

## Quality Gates Report Template

```
Quality Gates Report
════════════════════
Overall:  [READY / NOT READY]

Gates:
  Code:     [PASS/FAIL] — lint, types, format
  Tests:    [PASS/FAIL] — [N] passed, [N] failed
  Coverage: [PASS/FAIL] — [N]% (threshold: 80%)
  Security: [PASS/FAIL] — secrets, vulnerabilities
  Docs:     [PASS/WARN] — changelog, readme
  Build:    [PASS/FAIL] — compilation
```

## Verdict Rules

- **READY:** All required gates (Code, Tests, Security, Build) pass; Coverage meets threshold; Docs pass or WARN only.
- **NOT READY:** Any required gate fails OR coverage below threshold. List specific failures and fix suggestions.

## Failure Reporting

If any gate fails, include:

1. **Failed gate name** — e.g., "Tests: FAIL"
2. **Specific error** — e.g., "Jest: 5 tests failing in `src/__tests__/auth.test.ts`"
3. **Fix suggestion** — e.g., "Run `npm test -- --watch` to debug, or see test output above"

## Example: All Passing

```
Quality Gates Report
════════════════════
Overall:  READY

Gates:
  Code:     PASS — eslint (0 warn), tsc (0 err), prettier (clean)
  Tests:    PASS — 287 passed
  Coverage: PASS — 84% (threshold: 80%)
  Security: PASS — no secrets, no high-severity audits
  Docs:     PASS — CHANGELOG.md updated, README current
  Build:    PASS — npm run build (0 err)
```

## Example: With Failures

```
Quality Gates Report
════════════════════
Overall:  NOT READY

Gates:
  Code:     FAIL — eslint: 3 errors in src/lib/api.ts (line 42: unused var)
  Tests:    FAIL — 5 tests failing in __tests__/auth.test.ts (see output above)
  Coverage: FAIL — 72% (threshold: 80%)
  Security: PASS — no secrets found
  Docs:     WARN — CHANGELOG.md not updated
  Build:    PASS — npm run build (0 err)

Blockers:
  1. Fix ESLint errors: run `npx eslint --fix` or edit line 42
  2. Debug failing tests: run `npm test -- --watch src/__tests__/auth.test.ts`
  3. Increase coverage: add tests to cover remaining 8% of src/lib/
  4. Update CHANGELOG.md with summary of changes
```
