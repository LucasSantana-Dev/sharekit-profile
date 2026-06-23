---
name: mutation-test
description: Run mutation testing against a project's test suite to verify the tests actually catch failures when source code is broken. Use after major test changes, before declaring a suite "good", or when coverage % looks healthy but you suspect tests aren't catching real bugs.
user-invocable: true
argument-hint: "[path/to/project] [--per-file <path>]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/mutation-test
---

# Mutation Test

Coverage % tells you which lines were executed. Mutation testing tells you whether the
tests would have caught the line being broken. It's the only objective answer to "are
these tests actually protective?"

A test suite with 95% coverage and 30% mutation score is mostly assertion-free coverage
padding. A suite with 70% coverage and 85% mutation score genuinely guards behavior.

## Use When

- After running `/test-cleanup` to validate that surviving tests are protective
- After `/generate-tests` to verify the new tests actually verify outcomes
- When coverage % is healthy but bugs still slip through to production
- Before promoting a project to "production-ready" or "v1.0"
- Periodically (quarterly) on critical modules

## Do Not Use When

- The suite is currently red — fix failures first; mutation testing requires a green baseline
- The suite takes >10 min for a single run — mutation testing multiplies that by ~50;
  run `/test-cleanup` first
- You only need to find untested lines — use `/coverage-gap` instead (much faster)

## Inputs / Prereqs

- Test suite must be green
- Suite runtime should be <5 min for a single run, ideally <1 min
- Mutation framework installed (skill installs if missing)
- `--per-file <path>` flag: only mutate one file/module (much faster, recommended for
  first-time runs and for diffing PRs)

---

## Workflow

### 1. Detect language and pick the framework

| Language | Framework | Install |
|---|---|---|
| TypeScript / JavaScript | Stryker | `npm i -D @stryker-mutator/core @stryker-mutator/jest-runner` (or `vitest-runner`) |
| Python | mutmut | `pip install mutmut` |
| Go | go-mutesting | `go install github.com/zimmski/go-mutesting/...@latest` |
| Rust | cargo-mutants | `cargo install cargo-mutants` |
| Java / Kotlin | PIT | maven/gradle plugin |
| Ruby | mutant | `gem install mutant-rspec` |

```bash
# Detect what's already configured
ls stryker.conf.* .stryker* mutmut_config.py cargo-mutants.toml 2>/dev/null
```

### 2. Confirm baseline is green

```bash
npm test 2>&1 | tail -5     # or pytest, go test, cargo test
```

Stop if any test fails. Mutation testing requires that all tests pass on the unmodified
source — otherwise mutation kills are indistinguishable from real failures.

### 3. Configure (Stryker example)

If `stryker.conf.json` doesn't exist, create one. **Default to per-file mode** for the
first run; full-suite mutation can take hours on a large codebase.

```json
{
  "mutate": ["src/**/*.ts", "!src/**/*.spec.ts", "!src/**/*.test.ts"],
  "testRunner": "jest",
  "reporters": ["clear-text", "progress", "html"],
  "coverageAnalysis": "perTest",
  "concurrency": 4,
  "timeoutMS": 30000,
  "thresholds": { "high": 80, "low": 60, "break": 50 }
}
```

For Vitest replace `"jest"` with `"vitest"` and install `@stryker-mutator/vitest-runner`.

For per-file mode (the recommended default):

```bash
npx stryker run --mutate "src/services/auth.ts"
```

### 4. Run

```bash
# Full project (use only if suite runs in <1 min)
npx stryker run

# Per-file (recommended default; ~50x faster)
npx stryker run --mutate "src/<module>/<file>.ts"

# Per-directory
npx stryker run --mutate "src/services/**/*.ts"

# Python
mutmut run --paths-to-mutate src/auth.py

# Go
go-mutesting ./internal/auth/...

# Rust
cargo mutants --file src/auth.rs
```

Mutation testing is slow (typically 30–60× the suite runtime). For a 30-second suite
mutating one file with 100 mutants, expect ~5–15 minutes.

### 5. Read the report

Stryker outputs an HTML report at `reports/mutation/mutation.html` and a console summary:

```
Mutation score:        72.3%   (target: >80%)
Killed:                145
Survived:              42      ← these are the problems
No coverage:           12      ← lines not executed by any test
Timeout:               3
```

**Score interpretation:**
- **>80%** — suite is genuinely protective; ship it
- **60–80%** — acceptable; investigate the top survivors
- **<60%** — significant portions of the suite are not catching failures; act on it

### 6. Act on survivors

Open the HTML report and group survivors:

**Survivor type A — Equivalent mutants** (rare, ~5% of survivors)
The mutated code is behaviorally identical to the original (e.g., `i <= n - 1` vs `i < n`).
No test can kill these. Mark as ignored in config.

**Survivor type B — Missing assertion**
A test executes the line but never asserts on the resulting behavior. Most common cause.
Add a meaningful assertion to the existing test, or write a new one.

**Survivor type C — Mocked-out behavior**
The line ran inside a mock that returned a stubbed value, so the mutation didn't affect
output. Replace the mock with a real call, or assert on the side effect that the real
implementation would produce.

**Survivor type D — Trivially weak test**
The test exists but only checks `toBeDefined()` or similar. Hand off to `/test-cleanup`
to delete it, then write a real replacement with `/generate-tests`.

For each survivor, prefer the order: **fix the test → delete the test → ignore the mutant**.
Ignoring should be rare and always documented.

### 7. Re-run after fixes

```bash
npx stryker run --mutate "src/<file>"
```

Confirm the score crossed the threshold. If still below, repeat step 6 on the new
survivor list.

### 8. CI integration (optional follow-up)

For modules below the project's mutation threshold, add a CI job that runs mutation
testing on changed files in PRs:

```yaml
# .github/workflows/mutation.yml
on: pull_request
jobs:
  mutation:
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - name: Find changed source files
        run: |
          git diff --name-only origin/main...HEAD \
            | grep -E "^src/.*\.ts$" \
            | grep -v "\.spec\.\|\.test\." > changed.txt
      - name: Mutate changed files
        run: npx stryker run --mutate "$(cat changed.txt | tr '\n' ',')"
```

This keeps full-suite mutation cost out of CI while catching new shallow tests at
PR time.

---

## Outputs / Evidence

- Mutation score per file or whole project
- HTML report at `reports/mutation/mutation.html`
- List of survivors classified by type (equivalent / missing assertion / mocked-out /
  trivially weak)
- Specific test edits or deletions recommended
- Updated score after fixes

## Failure / Stop Conditions

- Suite is red on the unmodified source — fix failures first
- Suite runtime is so high that mutation would take >2 hours — stop and recommend
  `/test-cleanup` first
- Mutation framework cannot be installed (network, OS, etc.) — report blocker
- For per-file runs that complete with 100% score: report and move to next file or stop
  if all targeted files are clean

## Memory Hooks

- Write memory with the per-module mutation score so future sessions can see trend
- Read prior scores to surface regression in the report (e.g., "auth.ts dropped from
  89% to 64% — investigate recent changes to its test file")
