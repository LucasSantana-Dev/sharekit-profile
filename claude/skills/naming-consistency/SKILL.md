---
name: naming-consistency
description: >-
  Detect naming conventions from existing code, then audit new or all symbols for violations. Reports inconsistencies across files without enforcing a single style. Use when reviewing a PR for naming regressions, auditing a module before a refactor, or establishing a naming baseline. Triggers: "naming consistency", "naming audit", "naming violations", "inconsistent names", "naming conventions", "check naming".
metadata:
  owner: global-agents
  tier: ephemeral
  canonical_source: ~/.claude/skills/naming-consistency
---

# Naming Consistency

Detect the conventions already in use, then find violations.

## Workflow

1. **Sample existing symbols** — read 10-20 representative files to extract function, variable, class, and file names. Don't read the whole codebase.

2. **Infer conventions** per symbol category:
   - Functions/methods: camelCase, snake_case, PascalCase, kebab-case?
   - Classes/types: PascalCase, ALL_CAPS, snake_case?
   - Constants: SCREAMING_SNAKE, camelCase, PascalCase?
   - Files: kebab-case, snake_case, PascalCase, camelCase?
   - Test files: `*.test.*`, `*.spec.*`, `*_test.*`?

3. **Scan the target scope** — if given a PR diff, scan only changed files. Otherwise scan the specified directory.

4. **Flag violations** — any symbol that doesn't match the inferred convention for its category.

5. **Flag internal inconsistencies** — multiple conventions used within the same file or the same module.

## Output

```
Naming Consistency Report
──────────────────────────
Detected conventions:
  Functions:  camelCase (87% of sample)
  Classes:    PascalCase (100% of sample)
  Constants:  SCREAMING_SNAKE (72%) or camelCase (28%) — inconsistent
  Files:      kebab-case (95%)

Violations:
  src/utils/DataHelper.ts     — file: PascalCase (expected kebab-case)
  src/auth/user-service.ts:42 — function `Get_User` (expected camelCase)
  src/api/router.ts:15        — const `defaultTimeout` (expected SCREAMING_SNAKE)

Internal inconsistencies:
  src/db/schema.ts — uses both camelCase and snake_case for field names
```

## Rules

- Infer; don't impose. If the codebase uses snake_case, violations are camelCase — not the other way around.
- Majority wins: if 60%+ of a category uses one convention, that's the baseline.
- Mixed-convention constants (e.g., both SCREAMING_SNAKE and camelCase) → flag as "inconsistent baseline" rather than picking a winner.
- Do not rename. Report only.
