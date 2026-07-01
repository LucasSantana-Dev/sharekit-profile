# Code Quality & Review Skills

Use after writing code, before merging, or when simplifying existing code. Archived wrappers such as `code-review`, `refactor-pipeline`, and `verify-before-done` are folded into active skills.

---

## /review

Code review that prioritizes bugs, regressions, security issues, logic errors, and maintainability over style.

**Severity ordering:** correctness/regression > security > data loss > performance > style.

**Output:** Severity-rated findings with file paths and concrete remediation.

---

## /refactor

Surgical code improvement without changing behavior.

**Scope:** A focused function, class, module, or small diff.

**Use with:** `/request-refactor-plan` and `/orchestrate` for broad or cross-module refactors.

---

## /request-refactor-plan

Plan a multi-file refactor with sequencing, rollback, validation, and ownership boundaries.

**When to use:** Before refactoring 3+ files, crossing module boundaries, or touching architecture.

---

## /verify

Run the narrowest meaningful validation sequence before merge, release, or handoff.

**Validates:** lint/type/build/tests/docs/security evidence appropriate to the change.

---

## /quality-assurance

Choose and sequence the right QA checks for a change, release, incident, or maintenance sweep.

**Output:** QA plan, chosen gates, evidence required, residual risk.

---

## /quality-gates

Run repository-native verification gates such as formatting, lint, type-check, tests, build, docs, CI, and security scans.

**Principle:** native repo commands first; external scanners are supporting evidence.

---

## /ponytail

Minimalism and over-engineering control. Use audit/review mode for bloat scans, diff complexity checks, and deletion opportunities.

---

## /impeccable

Polish frontend interfaces: UX review, visual hierarchy, accessibility, responsive behavior, and design-system fit.

**Last updated:** 2026-07-01
