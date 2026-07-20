# Testing

- Test business behavior and failure modes, not trivia.
- Add or update tests when you change logic, contracts, or critical workflows.
- Prefer repo-native test commands and realistic fixtures.
- Fix flaky tests instead of normalizing them.
- Coverage is a signal, not the goal; protect critical paths first.

## Proportionality

Keep test count proportional to the feature's real complexity. A bloated suite costs more than no suite (false confidence, slow CI, maintenance burden).

| App type | Source LOC | Reasonable test count |
|---|---|---|
| Discord bot (≤30 commands) | ~5k | 50–200 |
| Browser extension | ~3k | 40–150 |
| REST API (≤20 routes) | ~4k | 80–250 |
| CLI tool | ~2k | 30–120 |
| Full-stack app | ~15k | 200–600 |

When a project exceeds these ranges, run `/test-cleanup` before adding more tests.

## Anti-patterns — do not write these

- **Mock the thing under test**: `jest.mock('../myService')` where `myService` is the file being tested
- **Assertion-free mocks**: tests whose only assertion is `expect(mock).toHaveBeenCalled()` with mocked input
- **Trivial pass-throughs**: testing `return this.dep.method(args)` when the wrapper has no logic
- **Getter/setter tests**: no validation logic means no test needed
- **Type-check tests**: TypeScript already enforces these at compile time
- **Filler assertions**: `expect(true).toBe(true)`, `expect(1).toBe(1)`, empty `it()` bodies
- **Snapshot bloat**: snapshot tests for pure data transformations with no dynamic output
- **Coverage padding**: tests added solely to hit a percentage target with no behavioral value
