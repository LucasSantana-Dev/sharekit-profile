---
name: generate-tests
description: Analyze code changes and propose or generate meaningful tests that cover
  business behavior, edge cases, and regressions. Use when the user wants test additions
  driven by a concrete implementation or diff.
argument-hint: '[<file-or-function>]'
metadata:
  owner: global-agents
  tier: ephemeral
  canonical_source: ~/.agents/skills/generate-tests
---

# Generate Tests

Analyze code and generate comprehensive tests covering business logic, edge cases, and error conditions.

## Process

### 1. Detect stack and runner

```bash
grep -E "vitest|jest|pytest|rspec|mocha" package.json pyproject.toml Cargo.toml go.mod 2>/dev/null | head -3
find . \( -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" \) \
  2>/dev/null | grep -v node_modules | head -5
```

Confirm the runner and naming convention before writing any tests.

### 2. Identify target

- If `--pr N`: run `gh pr diff N` to get changed files; identify new or modified functions in each
- Otherwise: read the source file(s) or locate the named function via search

For each target:
- Identify public API surface
- Map dependencies and side effects
- Check which branches and paths existing tests already cover (avoid duplicates)

### 3. Test Strategy
- **Unit tests**: Pure functions, business logic, data transformations
- **Integration tests**: API endpoints, database operations, service interactions
- **Edge cases**: Empty inputs, boundary values, error conditions
- **Error handling**: Exception paths, timeout behavior, retry logic

### 3. Generate Tests

Follow project conventions:
- Read AGENTS.md/CLAUDE.md for testing framework and patterns
- Match existing test file naming (`*.test.ts`, `*.spec.ts`, etc.)
- Use realistic test data reflecting actual usage
- Keep test count proportional to the feature's complexity — do not pad for a coverage number

### 4. Verify

```bash
# Run the generated tests
<project test command>

# With coverage delta (if threshold is configured)
<project test command> --coverage 2>&1 | grep -E "Statements|Branches|Functions|Lines"
```

Report coverage before and after to show the delta.

## Rules

- Test behavior, not implementation details
- Don't test trivial getters/setters/enums
- Use descriptive test names that explain the scenario
- Mock external dependencies, not internal modules
- Include both happy path and error cases
- Do not mock the thing under test — if the module is what you're testing, don't mock it
- Do not write filler assertions (`expect(true).toBe(true)`, assertion-free mock checks)
- Prefer one integration test over five mocked-everything units for any flow that crosses a boundary

## Outputs / Evidence

- Return the checks run, evidence captured, blockers found, and the next required action.

## Failure / Stop Conditions

- Stop if required credentials, environment access, or prerequisite context are missing.
- Stop if the workflow would report unverified work as complete.
- Do not bypass required gates or safeguards unless the user explicitly asks for it.
