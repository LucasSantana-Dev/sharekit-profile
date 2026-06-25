# Code Quality & Review Skills

Use after writing code or before merging. `verify` is the lightweight pre-merge gate; `refactor-pipeline` is the full composite for larger cleanups. `code-review` for reviewing others' work.

---

## /code-review

Code review that prioritizes bugs, regressions, security issues, and logic errors over style.

**Severity ordering:** Bugs > regressions > security > performance > style

**Coverage:**
- Logic defects (incorrect conditions, off-by-one, etc.)
- SOLID principle violations
- Performance anti-patterns
- Type safety issues
- Unsafe async/concurrency patterns

**When to use:** Before merge, as second opinion, quality gate

**Output:** Severity-rated findings organized by type

---

## /refactor

Surgical code improvement without changing behavior — eliminate code smells while preserving behavior.

**Scope:** Single function/module/class; focused cleanups

**Refactorings:**
- Extract method / variable
- Rename for clarity
- Remove dead code
- Simplify conditionals
- Consolidate duplicates

**When to use:** Code "smells" but works correctly

**Output:** Refactored code (same behavior, better clarity)

---

## /refactor-plan

Plan a multi-file refactor with proper sequencing and rollback steps.

**When to use:** Before refactoring 3+ files or cross-module boundaries

**Identifies:**
- Files to change + sequencing
- Breaking changes + mitigations
- Rollback steps per file
- Testing strategy

**Output:** Phased refactor plan + rollback procedures

---

## /refactor-pipeline ⭐⭐ **Composite**

Safely refactor a module end-to-end: plan → three-man-team → fix-the-suite → ADR → docs-sync.

**Phases:**
1. **Discovery:** RAG search for prior context + protected scopes
2. **Planning:** Refactor plan with rollback steps
3. **Critic gate:** Architecture review before execution
4. **Execution:** 3-agent team (architect, builder, reviewer) in parallel
5. **Testing:** Audit + prune test suite, run mutation testing
6. **ADR:** Write architecture decision record
7. **Sync:** Propagate docs to all mirror locations

**When to use:** Multi-file refactor (>5 files or cross-module)

**Output:** Refactored code + ADR + updated docs

---

## /verify

Run the narrowest meaningful validation sequence before merge, release, or handoff.

**Validates:**
- Type checking (tsc, mypy, etc.)
- Linting (eslint, pylint, etc.)
- Unit tests pass
- No obvious regressions

**When to use:** Quick pre-merge check (lightweight version of verify-before-done)

**Output:** PASS/FAIL verdict

---

## /verify-before-done ⭐ **Composite**

Pre-ship verification gate: lint/type/build → tests → coverage → Sonar → CI → Sentry.

**Stages (run sequentially):**
1. Type-check + lint
2. Build project
3. Run test suite
4. Coverage threshold check
5. SonarCloud gate scan
6. GitHub CI checks pass
7. Sentry error monitoring (post-deploy)

**When to use:** Before merge or release

**Output:** Binary PASS/FAIL verdict + blockers

---

## /quality-assurance

Choose and sequence the right QA skills and checks for a change or release.

**Considers:**
- Change scope (file count, risk)
- Change type (feature, fix, refactor)
- Project stage (pre-release, post-release)

**Recommends:** Which checks to run + order

**Output:** QA checklist for the change

---

## /quality-gates

Run repository-native verification gates such as lint, type-check, and tests.

**Runs:**
- ESLint / Pylint / etc. (style)
- TypeScript / mypy / etc. (types)
- Jest / Vitest / etc. (unit tests)
- Coverage threshold checks

**When to use:** Standalone quality gate (before verify-before-done)

**Output:** Gate results + pass/fail per check

---

## /code-security

Security guidelines for writing secure code — OWASP, XSS, SQL injection, auth, and more.

**Covers:**
- OWASP Top 10 implementation
- Auth/session handling
- Credential + secret management
- Input validation + sanitization
- Error handling (no information leakage)

**When to use:** Writing auth, API, or infra code

**Output:** Security checklist + best practices

---

## /receiving-code-review

Evaluate incoming code review feedback before acting on it.

**Process:**
1. Read all comments
2. Assess validity + priority
3. Identify conflicts or unclear feedback
4. Plan remediation

**When to use:** After receiving review feedback on a PR

**Output:** Prioritized action plan for addressing feedback

---

## /requesting-code-review

Use when completing tasks, implementing major features, or before merging — structures the review request.

**Structures:**
- Clear summary of change
- Why the change (link to issue)
- Key decisions + trade-offs
- Testing + verification done

**When to use:** Before opening PR for human review

**Output:** Well-structured review request

---

## /improve-codebase-architecture

Find deepening opportunities informed by CONTEXT.md and ADRs — refactoring, testability, module consolidation.

**Discovers:**
- Tight coupling that could be loosened
- Modules that could be consolidated
- Test coverage gaps
- Architectural anti-patterns

**When to use:** Post-feature-delivery cleanup

**Output:** Prioritized list of architectural improvements

---

## /impeccable

Polish frontend interfaces: UX review, visual hierarchy, accessibility, responsive behavior, design systems.

**Audits:**
- Visual hierarchy (contrast, sizing, weight)
- Accessibility (WCAG, keyboard nav, screen readers)
- Responsive behavior (mobile, tablet, desktop)
- Design system compliance (tokens, components)
- Interaction patterns (hover, focus, animations)

**When to use:** Before shipping UI; design polish pass

**Output:** Polish checklist + recommended improvements

---

**Last updated:** 2026-06-25
