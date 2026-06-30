---
name: test-cleanup
description: Audit and prune a bloated test suite down to the minimum tests that hit the coverage threshold and guard real behavior. Replaces many shallow unit tests with fewer well-scoped integration tests. Use when test count is disproportionate to app size.
user-invocable: true
argument-hint: "[path/to/tests] [--dry-run]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/test-cleanup
---

# Test Cleanup

**Goal: hit the coverage threshold with the fewest, fastest tests possible.**

Not zero tests. Not maximum deletion. The minimum set of well-written tests that:
1. Reach the project's coverage target
2. Guard real behavior and regressions
3. Run fast enough that nobody skips them

A bloated suite of 1.4k shallow tests gives worse protection than 150 integration tests
that actually exercise real code paths. Many shallow tests count coverage lines the same
way one integration test does — but the integration test finds real bugs.

---

## Step 1 — Detect runner and gather baseline numbers

Identify the test runner before running anything:

| Signal | Runner |
|---|---|
| `vitest` in `package.json` | Vitest — `npx vitest run --coverage` |
| `jest` in `package.json` | Jest — `npx jest --coverage --verbose` |
| `pytest.ini` / `pyproject.toml [tool.pytest]` | pytest — `pytest --cov` |
| `Cargo.toml` | Rust — `cargo test` |
| `go.mod` | Go — `go test ./... -cover` |

```bash
# Find runner
grep -E "\"vitest\"|\"jest\"|\"mocha\"|\"pytest\"" package.json pyproject.toml 2>/dev/null | head -3
ls pytest.ini go.mod Cargo.toml 2>/dev/null

# Check coverage threshold config
grep -r "coverageThreshold\|threshold\|coverage" jest.config* vitest.config* package.json \
  2>/dev/null | grep -v node_modules | head -10

# Run with coverage and timing (adjust command for your runner)
npm test -- --coverage --verbose 2>&1 | tee /tmp/test-baseline.txt
tail -30 /tmp/test-baseline.txt

# Pull the key numbers
grep -E "Tests:|Test Suites:|Time:" /tmp/test-baseline.txt
grep -E "Statements|Branches|Functions|Lines" /tmp/test-baseline.txt

# Current test count (JS/TS)
grep -r "^\s*it\(\|^\s*test\(" --include="*.spec.*" --include="*.test.*" . \
  | grep -v node_modules | wc -l

# Source LOC (not tests, not generated)
find src -name '*.ts' -not -path '*/spec*' -not -path '*/test*' \
  | xargs wc -l 2>/dev/null | tail -1
```

Record all four baseline metrics before touching anything:
- **Test count**
- **Suite runtime** (seconds)
- **Coverage %** (lines or statements — whichever the threshold uses)
- **Source LOC**

See [references/lookup-tables.md](references/lookup-tables.md#efficient-test-count-by-app-type) for the proportionality lookup table by app type.

**Plan: reach the count target while maintaining coverage and cutting suite runtime.**

---

## Step 2 — Reality check: is the target reachable under the current gate?

Before touching anything, verify the proportionality target is achievable given the
project's coverage threshold. This is the most common reason cleanup stalls.

```bash
# Count testable functions in the covered source
find src extension lib -name '*.ts' -o -name '*.js' 2>/dev/null \
  | grep -vE "spec|test|__tests__|node_modules" \
  | xargs grep -cE "^\s*(function|const \w+ = \(|export (default )?(function|const)|class \w+)" \
    2>/dev/null | awk -F: '{s+=$2} END {print s}'
```

**Compatibility check:**

If the gate is `functions: ≥99%` and source has 1500 functions, the suite **cannot**
have fewer than ~1485 tests unless you write integration tests that each cover multiple
functions. The proportionality target is then mathematically unreachable without one of:

- **Lowering the gate** to a number compatible with the target (e.g., functions ≥85%)
- **Excluding more files** from coverage measurement (generated types, DTO files,
  constants, migration scripts)
- **Writing integration tests aggressively** so each test covers many functions

See [references/lookup-tables.md](references/lookup-tables.md#coverage-exclusion-patterns) for coverage exclusion patterns that avoid lowering the threshold.

**If incompatible, STOP and surface the conflict explicitly to the user before pruning:**

```
COVERAGE/TARGET CONFLICT

Project gate:        functions ≥99% over <path>
Functions in scope:  1480
Implied min tests:   ~1480 (1 per function) or ~150 with 10x integration coverage
Proportionality:     40–150

The current gate makes the proportionality target unreachable through deletion alone.
Choose one before continuing:

  A) Exclude generated/logic-free files from coverage scope (preferred)
  B) Lower the gate to <X>% (writes a recommended config patch)
  C) Commit to writing integration tests during this pass
  D) Accept higher count; cap deletion at obvious waste only

Default if no answer: A (add exclusions), then continue against the updated gate.
```

Do not start deletion until this is resolved.

---

## Step 3 — Delete skipped and pending tests immediately

Before any analysis, sweep for dead tests. These have zero coverage contribution and zero
behavioral value. Delete without checking anything else.

```bash
# JS/TS
grep -rn "it\.skip\|xit\|xdescribe\|describe\.skip\|test\.skip\|it\.todo\|test\.todo" \
  --include="*.spec.*" --include="*.test.*" . | grep -v node_modules

# Python
grep -rn "@pytest.mark.skip\|@pytest.mark.xfail" --include="*.py" . | grep -v __pycache__
```

Delete the entire `it.skip` / `xit` / `xdescribe` block for each hit. If an `xdescribe`
wraps the whole file, delete the file.

These are tests someone broke and never fixed, or wrote and never enabled. They're not
coming back.

---

## Step 4 — Use test names as a triage signal

Bad names reliably indicate bad tests. Scan for them to decide which files to audit first.

```bash
grep -rn "should work\|test 1\|test 2\|handles the case\|it works\|works correctly\
\|does the thing\|basic test\|simple test\|dummy\|placeholder\|TODO\|FIXME" \
  --include="*.spec.*" --include="*.test.*" . | grep -v node_modules
```

Files with many hits go to the top of the audit queue. A test named "should work" almost
never tests anything meaningful. Bad naming is a reliable fast-path to the worst offenders.

---

## Step 5 — Delete whole files

Assess entire files before reading individual tests.

**Delete the whole file if:**
- The source file it tests no longer exists
- Every test mocks the module under test (nothing real is being tested)
- It only tests TypeScript types, interfaces, or enums (the compiler handles this)
- It is a structural duplicate of another spec file with >70% overlap
- All tests are `toBeDefined()`, `toBeInstanceOf()`, or similar filler

```bash
# Find orphaned spec files (source file gone) — JS/TS
for f in $(find . -name '*.spec.ts' | grep -v node_modules); do
  src="${f/.spec.ts/.ts}"
  src="${src/\/__tests__\//\/}"
  [ ! -f "$src" ] && echo "ORPHAN: $f"
done

# Python
for f in $(find . -name 'test_*.py' | grep -v __pycache__); do
  module=$(echo "$f" | sed 's/test_//' | sed 's/_test//')
  [ ! -f "$module" ] && echo "ORPHAN: $f"
done
```

---

## Step 6 — Delete waste patterns within remaining files

Within each file, delete `it()` blocks matching these patterns.

### Mocked-everything units (largest source of bloat)

The file under test is mocked inside its own spec — nothing real runs:
```ts
jest.mock('../myService')  // myService is what this file is supposed to test
```
Delete every test in that describe block. If the whole file is this pattern, delete the file.

Only assertion is that a mock was called with its own mock input:
```ts
expect(mockSendEmail).toHaveBeenCalledWith(mockPayload)
// where mockPayload is defined in the same test
```
This is circular. Delete.

### Filler assertions

```ts
expect(result).toBeDefined()
expect(result).not.toBeNull()
expect(true).toBe(true)
expect(service).toBeInstanceOf(MyService)
expect(typeof handler).toBe('function')
```

### Trivial structure tests

```ts
it('should be defined', () => { expect(service).toBeDefined() })
it('should create an instance', () => { expect(new MyClass()).toBeInstanceOf(MyClass) })
it('should return the id', () => { expect(obj.getId()).toBe(obj.id) })
```

### Redundant same-path tests

3+ tests exercise the identical code path with cosmetically different inputs. Keep 1:

```ts
it('formats Alice', () => expect(format('Alice')).toBe('Alice'))
it('formats Bob',   () => expect(format('Bob')).toBe('Bob'))
it('formats Carol', () => expect(format('Carol')).toBe('Carol'))
```
→ Keep 1.

### Snapshot bloat

`toMatchSnapshot()` on pure data transformations or serialized plain objects where the
snapshot is just a stringified version of the input. Delete unless the rendered output
is itself the contract (CLI help text, email templates, PDF output).

### Slow test smell

```bash
grep -rn "sleep\|setTimeout\|setInterval\|waitFor.*\d{4,}" \
  --include="*.spec.*" --include="*.test.*" . | grep -v node_modules
```

Tests with multi-second waits are usually testing timing rather than behavior. Delete the
timing-dependent tests; fix the source code if it has a hardcoded delay.

---

## Step 7 — What to keep

A test earns its place if it meets **at least one** of these:

1. **Catches a real bug** — mental test: delete the entire production implementation. Would this test fail? If yes, keep it. If the test would still pass (because it mocks the implementation), delete it.
2. **Documents a non-obvious invariant** — the test name explains a constraint that isn't obvious from reading the source (e.g., "rejects usernames longer than 32 chars", "returns empty list rather than null when no results").
3. **Guards a known regression** — the test was written because a bug was previously reported and fixed. Comment should reference the incident or issue.
4. **Covers a critical path** — auth, payment, data mutation, destructive operations. Even if simple, keep it.

A test is waste if it:
- Would pass even if the production code deleted its entire implementation
- Tests the language or framework, not the application ("instantiates correctly")
- Has a hardcoded expected value that is just the input reflected back
- Was written to hit a coverage number (you can tell by the name)

When in doubt about a specific test, apply the "delete the production branch" mental test:
delete the implementation, run the test. If it still passes → delete the test.

---

## Step 8 — Check coverage after each batch of deletions

After deleting a batch (every 5–10 files):

```bash
npm test -- --coverage 2>&1 | tail -10
```

If coverage drops **below the threshold**, that batch deleted sole coverage contributors.
Two options:

**Option A — Write one replacement integration test** covering those paths as a natural
side effect of exercising a real flow. One integration test covering 80 lines is better
than 12 shallow mocks covering the same 80 lines one at a time.

**Option B — Restore the single best test from that batch** (not all of them) — the one
that covers the most uncovered lines with the least mocking.

Never restore a whole batch. Find the gap, fix it surgically.

---

## Step 9 — Write replacement integration tests (mandatory when stuck)

This step is **not optional** when the count target hasn't been reached and you're up
against the coverage gate. Bailing out with "further deletion needs replacement tests
and that's a separate scope" is the failure mode this skill exists to prevent.

When pure deletion stalls because the gate is binding:

1. **Identify the structural cluster** — group remaining tests by the source file or
   feature they cover. Look for groups of 5+ tests covering one module via different
   inputs/branches.

2. **Write the integration test that subsumes the cluster.** It should:
   - Enter through the public API of the module (exported function, command handler,
     route, message handler)
   - Drive the input that exercises every branch the cluster was covering, in one or
     a few realistic scenarios (table-driven `it.each` is fine — that's still one test)
   - Use real implementations of internal collaborators; mock only external boundaries
     (network, file system, time)
   - Assert on the observable output / side effect, not internal call sequences

3. **Delete the cluster.** All of it. Re-run coverage to confirm the gate still holds.
   If coverage drops, the integration test is missing a branch — extend it (don't
   restore the deleted unit tests).

4. **Repeat for every cluster** until either the count target is hit or every remaining
   test independently passes the Step 7 keep criteria.

**Target: each integration test covers at least 3× the lines of the tests it replaces,
at 1/5th the test count.** A 30-test cluster collapses into ~6 `it.each` rows in one
integration test, with same or better coverage.

### When to use `it.each`

If the cluster is "same code path, different inputs" (e.g., 30 tests of "this input
maps to that output"), `it.each` is a single test that covers all 30 cases without
paying the per-test setup cost:

```ts
it.each([
  ['input-a', 'output-a'],
  ['input-b', 'output-b'],
  // ...28 more rows
])('maps %s → %s', (input, expected) => {
  expect(transform(input)).toBe(expected)
})
```

Replaces 30 individual `it()` blocks with 1, no coverage loss.

### Failure modes when the agent stops here

If you find yourself writing "further deletion needs replacement integration tests and
that's separate scope" — that means you stopped exactly where the value was. The
replacement-test phase IS the cleanup.

---

## Step 10 — Consolidate fragmented spec files

After deletion, many files will have 2–3 surviving tests that all cover the same module.
A module with 5 spec files each containing 2 tests is harder to navigate than one spec
file with 10 tests.

```bash
find . -name '*.spec.ts' | grep -v node_modules \
  | sed 's/\.spec\.ts//' | sed 's/\/__tests__\//\//' \
  | sort | uniq -d
```

For each module with multiple sparse spec files:
1. Merge all surviving tests into the primary spec file
2. Deduplicate `beforeEach` setup
3. Delete the now-empty secondary spec files

Do not consolidate files that are intentionally separated (unit vs. integration for the
same module where the separation is meaningful). Merge only when the split is arbitrary.

---

## Step 11 — Final count, timing, and coverage

```bash
npm test -- --coverage --verbose 2>&1 | tee /tmp/test-after.txt
grep -E "Tests:|Test Suites:|Time:" /tmp/test-after.txt
grep -E "Statements|Branches|Functions|Lines" /tmp/test-after.txt

grep -r "^\s*it\(\|^\s*test\(" --include="*.spec.*" --include="*.test.*" . \
  | grep -v node_modules | wc -l
```

Report:
- Test count: before → after (% reduction)
- Suite runtime: before → after (% faster)
- Coverage: before → after (must be ≥ threshold)
- Replacement integration tests written (count + what they cover)
- Files deleted entirely (count + dominant reason)
- Top 3 waste patterns by volume

**Success = count target hit AND coverage threshold maintained AND runtime reduced.**

If coverage is below threshold, write more integration tests before declaring done.
If count is above the proportionality target, continue deleting.

---

## Step 12 — Optional: mutation testing to validate the survivors

Run mutation testing against the cleaned suite to verify the tests that survived actually
catch failures when the source is broken.

```bash
# JavaScript/TypeScript — Stryker
npx stryker run

# Python — mutmut
mutmut run && mutmut results

# Go — go-mutesting
go-mutesting ./...
```

**Mutation score interpretation:**
- >80% — the suite is genuinely protective
- 60–80% — acceptable, some gaps remain
- <60% — significant portions of the surviving suite are not catching failures;
  run another deletion pass to remove tests with 0 mutation kills

---

## Failure / Stop Conditions

- If a deletion causes cascading failures in unrelated tests: shared state or bad
  isolation — fix the isolation, then continue deleting
- Writing integration tests is **never** out of scope for this skill. If you find
  yourself wanting to declare it so, that's the signal to do it now — see Step 9. The
  only valid stop conditions related to coverage are: (a) the user explicitly accepted
  a higher count in the Step 2 conflict resolution, (b) coverage gate has been lowered
  to a number compatible with the proportionality target, or (c) the remaining tests
  all pass the Step 7 keep criteria individually
- If coverage tooling cannot run at all (broken config, missing dependencies): stop and
  fix the tooling first; pruning blind to coverage is too risky
- If `--dry-run`: output the full deletion list and any replacement tests needed,
  without touching files

## Memory Hooks

- Write memory with: final test count, suite runtime, coverage %, and proportionality
  target so future sessions don't re-pad the suite
