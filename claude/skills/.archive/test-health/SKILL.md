---
name: test-health
description: Read-only diagnostic that reports the state of a project's test suite — count vs. proportionality, coverage vs. threshold, runtime, slowest tests, flaky test estimate, dead tests, and which other testing skills to run next. Use as the entry point before any test cleanup, generation, or mutation work.
user-invocable: true
argument-hint: "[path/to/project]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/test-health
---

# Test Health

A non-destructive checkup. Runs the diagnostics and tells you what (if anything) needs
attention — and which skill to run next. Makes no changes to source or tests.

## Use When

- You inherited a codebase and want to know how healthy its tests are
- A teammate said "the tests are slow" or "CI is flaky" and you need numbers, not vibes
- Before running `/test-cleanup`, `/mutation-test`, `/generate-tests`, or
  `/fix-the-suite` to confirm which one is actually needed
- Periodically (monthly/quarterly) as a regression check on suite quality

## Do Not Use When

- You already know what's wrong and want to fix it — go straight to the relevant skill
- The project has no tests yet — use `/generate-tests` or `/test-driven-development`

## Inputs / Prereqs

- Project must build and the test command must be runnable
- Coverage tooling is helpful but not required (skill notes if missing)
- Read access only

---

## Workflow

### 1. Detect stack and test command

```bash
# Identify project type
ls package.json pyproject.toml Cargo.toml go.mod 2>/dev/null

# Find test runner
grep -E "\"test\":" package.json 2>/dev/null
grep -E "jest|vitest|mocha|playwright" package.json 2>/dev/null | head -5
test -f pytest.ini && echo "pytest"
test -f Cargo.toml && echo "cargo test"
test -f go.mod && echo "go test"
```

### 2. Source size and proportionality target

```bash
# Source LOC (excluding tests, build output, dependencies)
find src lib app -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" \) 2>/dev/null \
  | grep -vE "spec|test|__tests__|node_modules|dist|build" \
  | xargs wc -l 2>/dev/null | tail -1

# Identify app type
grep -E "discord\.js|@discordjs|chrome\.runtime|webextension|express|fastify|nestjs\
|next|react|vue|svelte|cli|commander|yargs" package.json 2>/dev/null | head -5
```

Map to the proportionality table:

| App type | Source LOC | Healthy test count |
|---|---|---|
| Discord bot (≤30 commands) | ~5k | 50–200 |
| Browser extension | ~3k | 40–150 |
| REST API (≤20 routes) | ~4k | 80–250 |
| CLI tool | ~2k | 30–120 |
| Full-stack app | ~15k | 200–600 |

Record the **target range**. Compare current count to it.

### 3. Test count, runtime, coverage

```bash
# Test count
grep -rE "^\s*(it|test)\(" --include="*.spec.*" --include="*.test.*" . \
  | grep -v node_modules | wc -l

# Test files
find . \( -name "*.spec.*" -o -name "*.test.*" \) | grep -v node_modules | wc -l

# Run with coverage and timing
npm test -- --coverage --verbose 2>&1 | tee /tmp/test-health.txt
grep -E "Tests:|Test Suites:|Time:" /tmp/test-health.txt
grep -E "Statements|Branches|Functions|Lines" /tmp/test-health.txt | head -5

# Coverage threshold (target)
grep -A5 "coverageThreshold" jest.config* vitest.config* package.json 2>/dev/null | head -15
```

Record: test count, suite runtime, coverage % (lines/statements/branches), threshold %.

### 4. Slowest tests

```bash
# Jest/Vitest with verbose output shows per-test timing
grep -E "^\s+✓.*\(\d+\s*ms\)" /tmp/test-health.txt \
  | sed -E 's/.*\(([0-9]+) ms\).*/\1 &/' \
  | sort -rn | head -10
```

A single test taking >2s is suspect. The 10 slowest tests often account for half the
suite runtime — listing them by name shows where the time goes.

### 5. Dead test detection

```bash
# Skipped/pending tests (always-failing or never-running dead weight)
grep -rnE "it\.skip|xit|xdescribe|describe\.skip|test\.skip|it\.todo|test\.todo" \
  --include="*.spec.*" --include="*.test.*" . | grep -v node_modules | wc -l

# Tests with bad names (smell signal — usually low value)
grep -rnE "it\(['\"]should work|it\(['\"]test [0-9]|it\(['\"]works correctly\
|it\(['\"]basic test|it\(['\"]dummy" \
  --include="*.spec.*" --include="*.test.*" . | grep -v node_modules | wc -l

# Orphaned spec files (source counterpart deleted)
ORPHANS=0
for f in $(find . -name "*.spec.ts" 2>/dev/null | grep -v node_modules); do
  src="${f/.spec.ts/.ts}"; src="${src/\/__tests__\//\/}"
  [ ! -f "$src" ] && ORPHANS=$((ORPHANS+1))
done
echo "orphan spec files: $ORPHANS"
```

### 6. Flaky test estimate (light)

A full flake hunt belongs in `/fix-the-suite`. For a quick estimate, run the suite
3 times and compare:

```bash
for i in 1 2 3; do
  npm test 2>&1 | grep -E "Tests:" | tail -1
done
```

If pass/fail counts differ between runs, flag flakiness. If they match, mark as stable
(could still have rare flakes — only the deeper skill catches those).

### 7. Mocked-everything signal

```bash
# Files where the spec mocks the module under test (high-bloat indicator)
SUSPICIOUS=0
for f in $(find . -name "*.spec.ts" 2>/dev/null | grep -v node_modules); do
  base=$(basename "$f" .spec.ts)
  grep -q "jest\.mock\|vi\.mock" "$f" 2>/dev/null && \
    grep -q "['\"]\\.\\./$base['\"]" "$f" 2>/dev/null && SUSPICIOUS=$((SUSPICIOUS+1))
done
echo "spec files mocking their own SUT: $SUSPICIOUS"
```

---

## Health Score and Recommendation

Build a one-page report:

```
TEST HEALTH REPORT — <project>

App type:           <detected>
Source LOC:         <number>
Test count:         <current> (target: <range>)  → STATUS
Test files:         <count>
Suite runtime:      <seconds>                    → STATUS
Coverage:           <%> (threshold: <%>)         → STATUS

Dead weight:
  Skipped/pending:  <count>
  Bad-named tests:  <count>
  Orphaned specs:   <count>
  Mocked-SUT files: <count>

Flakiness (3 runs): STABLE / FLAKY (<n> tests differed)

Slowest 10 tests:
  <time>ms — <test name>
  ...

VERDICT: <one of>
  - HEALTHY:           No action needed.
  - BLOATED:           Run /test-cleanup
  - SLOW:              Run /test-cleanup focused on slow tests
  - FLAKY:             Run /fix-the-suite
  - LEAKY:             Run /test-isolation-fix
  - LOW COVERAGE:      Run /coverage-gap then /generate-tests
  - UNVALIDATED:       Run /mutation-test to confirm tests catch bugs
  - MULTIPLE ISSUES:   Run in this order: <ordered list>
```

### Status thresholds

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Count vs. target | within range | 1.5–3× ceiling | >3× ceiling |
| Runtime | <2 min | 2–5 min | >5 min |
| Coverage | ≥ threshold | within 5% | >5% below threshold |
| Skipped tests | 0 | 1–10 | >10 |
| Mocked-SUT files | 0 | 1–5 | >5 |

### Verdict mapping

- **>3× ceiling test count** OR **>5 mocked-SUT files** → BLOATED → `/test-cleanup`
- **Runtime >5 min** AND count is healthy → SLOW → `/test-cleanup` focused on slowest
- **Flaky in 3 runs** → FLAKY → `/fix-the-suite`
- **Coverage >5% below threshold** → LOW COVERAGE → `/coverage-gap` + `/generate-tests`
- **Healthy on all metrics but never validated** → UNVALIDATED → `/mutation-test`
- **Multiple issues** → ordered list (cleanup before generation, isolation before flake hunt)

---

## Outputs / Evidence

- Single one-page report with all metrics
- Explicit verdict and recommended next skill (or "no action needed")
- No changes to any file

## Failure / Stop Conditions

- Test command fails to run at all → report that and stop; recommend fixing the build first
- Coverage tooling not configured → report metrics without coverage; flag as a gap
- Suite takes >15 min to complete one run → cancel after first run, report partial data,
  recommend `/test-cleanup` immediately

## Memory Hooks

- Write memory with the report so subsequent runs can show trend (improving/regressing)
- Read prior reports to surface trend in the new report (e.g., "test count up 30% since
  last check")
