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

### 0. Check prior mutation scores (regression baseline)

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG unreachable"; exit 1; }
python3 ~/.claude/rag-index/query.py "mutation test score prior result" --top 5 --scope memory
```

If prior runs exist for this repo, note the prior score. If this run scores significantly
lower, investigate recent test changes. See `standards/skill-patterns.md §rag-first` and
`standards/skill-patterns.md §mount-guard`.

**Done when:** prior scores checked; regression noted (if any) or absence confirmed.

### 1. Detect language and pick the framework

See [references/frameworks.md](references/frameworks.md) for the full table, install commands,
and framework detection.

**Done when:** framework confirmed; tool installed and callable.

### 2. Confirm baseline is green

```bash
npm test 2>&1 | tail -5     # or pytest, go test, cargo test
```

Stop if any test fails. Mutation testing requires that all tests pass on the unmodified
source — otherwise mutation kills are indistinguishable from real failures.

**Done when:** all tests pass on unmodified source; baseline confirmed green.

### 3. Configure

See [references/configs.md](references/configs.md) for Stryker configuration, Vitest override,
and per-file mode examples.

**Done when:** mutation config file created or confirmed present; test mutate pattern verified.

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

**Done when:** mutation run completes; mutation.html report generated or console output captured.

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

**Done when:** score calculated; survivors identified and classified.

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

**Done when:** top survivors triaged; each assigned to a type and action (fix/delete/ignore).

### 7. Re-run after fixes

```bash
npx stryker run --mutate "src/<file>"
```

Confirm the score crossed the threshold. If still below, repeat step 6 on the new
survivor list.

**Done when:** score ≥ threshold (80%+) or survivors re-triaged.

### 8. CI integration (optional follow-up)

See [references/configs.md](references/configs.md) for the full CI workflow YAML.

This keeps full-suite mutation cost out of CI while catching new shallow tests at PR time.

**Done when:** CI workflow file (if configured) present in `.github/workflows/` and tested once.

---

## Outputs / Evidence

**Verdict:** Mutation score (>80% = protective / 60–80% = acceptable / <60% = act now)

**Top 3 findings:**
1. Highest-priority survivor type (A/B/C/D) and count
2. Recommended action (fix test / delete / replace mock / add assertion)
3. Estimated effort to close survivors

**Full evidence:** See `reports/mutation/mutation.html` for classified survivors, mutation details per file, and score trend if re-run.

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
