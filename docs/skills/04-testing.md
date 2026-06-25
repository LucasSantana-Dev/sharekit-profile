# Testing Skills

Reach for `test-health` first (read-only diagnostic), then `test-cleanup` to prune, `mutation-test` to validate survivors. `tdd` for new features built test-first. `fix-the-suite` is the composite for a full unhealthy suite.

---

## /tdd

Test-driven development with red-green-refactor loop.

**Cycle:**
1. **Red:** Write failing test (spec of desired behavior)
2. **Green:** Minimal code to make test pass
3. **Refactor:** Improve code under green (test still passes)
4. **Repeat:** Next test

**When to use:** Building any new feature or fixing bugs

**Enforces:** Tests first, code second (catches edge cases early)

**Output:** Well-tested, well-designed code

---

## /test-health

Read-only diagnostic reporting the state of a project's test suite — count, coverage, runtime, flakiness, dead tests.

**Metrics:**
- Test count (unit, integration, e2e)
- Coverage % (line, branch, function)
- Runtime (total, per-file, per-test)
- Flakiness % (tests that fail intermittently)
- Dead tests (no execution path)
- Test maintenance burden

**When to use:** Before any test work; start of sprint

**Output:** Test health report (no changes)

---

## /test-cleanup

Audit and prune a bloated test suite down to minimum tests that hit coverage threshold and guard real behavior.

**Process:**
1. Identify dead tests (unreachable code paths)
2. Merge redundant tests
3. Remove brittle tests (fragile to refactoring)
4. Verify coverage thresholds still met
5. Reduce suite runtime

**When to use:** Test suite slow (>5min), coverage high but suite large

**Output:** Pruned, faster test suite (same coverage)

---

## /test-gen

Generate missing tests for files, functions, or PRs using Vitest with coverage analysis.

**Analyzes:**
- Coverage gaps (untested branches)
- Risky functions (error handling, edge cases)
- PR changes (new/modified code)

**Generates:** Test cases for gaps

**When to use:** Closing coverage gaps before merge

**Output:** Generated test file + integration steps

---

## /generate-tests

Analyze code changes and propose or generate meaningful tests that cover the change.

**Process:**
1. Read the PR diff
2. Identify what changed (new functions, logic)
3. Propose test cases for changed behavior
4. Generate test file (or hand off spec for manual writing)

**When to use:** PR has new logic but lacks tests

**Output:** Test spec or generated test file

---

## /coverage-gap

Find and fill test coverage gaps for a PR by analyzing diffs and writing new tests.

**Process:**
1. Analyze PR diff
2. Identify untested branches
3. Write tests for gaps
4. Verify coverage increases

**When to use:** Coverage % didn't increase with PR

**Output:** New tests + coverage report

---

## /mutation-test

Run mutation testing to verify tests actually catch failures when source code is broken.

**How it works:**
1. Mutate source code (change > to <, remove condition, etc.)
2. Run test suite against mutation
3. Flag if test suite passes (mutation survived = test too weak)
4. Report mutation score (% killed)

**When to use:** After test-cleanup; before declaring suite production-ready; to validate test quality

**Output:** Mutation report + weak test identification

---

## /fix-the-suite ⭐⭐ **Composite**

Diagnose, repair, and validate a test suite: test-health → config-drift → test-cleanup → mutation-test → ADR.

**Phases:**
1. **Diagnosis:** Test health report (read-only)
2. **Config drift:** Audit jest/vitest thresholds, ESLint, tsconfig
3. **Cleanup:** Prune dead tests, refocus on behavior
4. **Mutation:** Validate survivors catch failures
5. **ADR:** Document testing philosophy + maintenance strategy

**When to use:** Test suite slow, flaky, or low-signal (high coverage but low confidence)

**Output:** Healthier, faster, higher-signal test suite + ADR

---

## /backend-testing

Comprehensive backend testing guidance for unit, integration, authentication, and API tests.

**Coverage:**
- Unit tests (individual functions)
- Integration tests (multi-module + database)
- API tests (endpoint contracts + status codes)
- Authentication tests (auth flows, permissions)
- Error handling (expected + unexpected errors)

**Patterns:**
- Test database isolation
- Mocking vs. integration trade-offs
- Async/concurrency testing
- Rate limiting testing

**When to use:** Building backend test strategy

**Output:** Backend testing reference + patterns

---

## /webapp-testing

Test a local web application with Playwright-based scripts, screenshots, and interaction flows.

**Capabilities:**
- Navigate + fill forms
- Take screenshots
- Verify element states
- Test interactions (click, hover, keyboard)
- Visual regression (screenshot comparison)

**When to use:** E2E verification before deploy; visual regression detection

**Output:** Test results + screenshots + failure logs

---

## /playwright-best-practices

Playwright testing guidance — E2E, component, API, visual, accessibility, security, and Electron testing.

**Coverage:**
- E2E browser testing patterns
- Component testing (unit + component)
- API request testing
- Visual regression + Percy integration
- Accessibility testing (WCAG)
- Security testing (CSRF, XSS, etc.)
- Electron app testing

**When to use:** Planning Playwright test strategy

**Output:** Testing reference + best practices

---

## /performance-test

Identify bottlenecks and gather performance metrics.

**Measures:**
- Load time (page, API)
- Time to interactive (TTI)
- Largest contentful paint (LCP)
- First input delay (FID)
- Database query time
- API response time

**Tools:** Lighthouse, Chrome DevTools, k6, Datadog, etc.

**When to use:** Before launch; performance regression detected

**Output:** Performance report + bottleneck identification

---

**Last updated:** 2026-06-25
