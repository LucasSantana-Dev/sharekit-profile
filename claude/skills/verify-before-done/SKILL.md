---
name: verify-before-done
description: 'Pre-ship gate: full matrix (lint, build, tests, coverage, sonar, CI, sentry) or quick mode (narrowest checks, PASS/FAIL/PARTIAL). Use for "is this ready?", verify, run checks, validate this.'
user-invocable: true
auto-invoke: pre-ship-verification + "is this ready" + "can I ship" + "before I merge" + "double-check before release" + "verify" + "run checks" + "validate this"
argument-hint: '[quick] [--strict] [--skip <gate1,gate2>]'
triggers:
  - is this ready
  - can i ship
  - before i merge
  - pre-ship check
  - verify before done
  - double-check before release
  - verify
  - run checks
  - validate this
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/verify-before-done
---

# Verify Before Done

Stops premature "done" claims by running the applicable quality checks and reporting
the result. Output shape depends on mode: quick mode emits one `PASS` / `FAIL` /
`PARTIAL` verdict; full mode emits a per-gate matrix (`PASS` / `FAIL` / `WARN` /
`PENDING` / `SKIP`) plus a `Verdict:` line.

Replaces:
- Manual "let me run tests" + "let me check CI" + "let me peek at Sonar" sequences
- Forgetting to check Sentry for new errors after the last push

## Mode selection (decide first)

- **quick**: argument `quick`, or a caller (for example `/ship` step 1) asks for quick
  mode, or a bare "verify", "run checks", "validate this".
- **full**: `--strict`, or any ship/merge/release readiness phrase ("is this ready",
  "can I ship", "before I merge/ship/release", "double-check before release").
- Conflict between signals: use **full**.

## When this fires

Auto-invoke when ANY apply:
- User says "is this ready", "can I ship", "can I merge", "before I release",
  "double-check before <verb>", "verify", "run checks", "validate this"
- A composite (`ship`, `ship-it`, `merge-confidently`, `release-cut`) is about to fire
  and the user wants a stricter check first
- A PR has been pushed and the user wants to verify before requesting review

## Rules for both modes

- **Read-only.** Never auto-fix gate failures; report and recommend only.
- A gate failing on code unrelated to the current change is named as pre-existing,
  with an explicit call on whether it blocks shipping.
- Never claim "verified" if a required gate was skipped for any reason other than
  "not applicable".
- Do not merge on `PARTIAL` (or any skipped required gate) without explicit user
  acknowledgement of what was skipped.

## Quick mode

Run in this order, stopping at the narrowest set that covers the risk.

State-check (quick mode only, run first): if the most recent CI run against the same
commit SHA is already fully green on all required gates and nothing changed since,
report "already verified at <sha>, skipping" and stop. Re-run only if code changed.

1. lint or static checks
2. type checks where applicable
3. targeted tests
4. broader tests only if risk warrants it
5. build/package checks if relevant
6. security checks when dependencies or config changed

Output is signal-first: verdict on line 1 (`PASS` / `FAIL` / `PARTIAL`), then only the
gates with signal (failures, warnings, skipped-but-required). Do not list gates that
passed cleanly.

```
PASS: all required gates green
  Skipped: security (no dep changes)

FAIL: 1 required gate failing
  type-check: packages/bot, 3 errors in src/foo.ts
```

## Full mode

The complete gate matrix (Phases 1 to 8). Always runs every applicable gate and always
emits the full matrix and the `Verdict:` line. No "already verified" short-circuit: a
green CI run on the same SHA only marks Phase 6 (CI) as `PASS (ci@<sha>)`; schema-drift,
scope, coverage, sonar and sentry still run.

## Workflow

### Phase 1 — Detect (always, composite logic only)

Detect which gates apply by reading the repo:

| Gate | Applies when | Skip when |
|------|--------------|-----------|
| **lint/type/build** | `package.json` with `typecheck`/`lint`/`build` scripts, `Cargo.toml`, `pyproject.toml`, `go.mod` | None of the above |
| **tests** | Any of `package.json` test script, `cargo test`, `pytest`, `go test` | No test runner detected |
| **coverage** | `vitest.config.*` with coverage thresholds, `jest.config.*` thresholds, `.coveragerc`, `pyproject.toml` `[tool.coverage]` | No coverage config |
| **sonar-check** | `sonar-project.properties` file present | Not present |
| **gh-fix-ci** | `gh pr view --json state,headRefName` returns a PR for current branch | No PR open or no `gh` |
| **sentry** | Env var `SENTRY_DSN` set OR `.sentryclirc` OR `sentry.properties` | Not configured |
| **schema-drift** | Server ORM present: Prisma `schema.prisma`, Django `migrations/`, SQLAlchemy `alembic/` | No ORM, or client-only store (Dexie/IndexedDB — e.g. Figurinhas) |
| **scope-consistency** | A plan under `.claude/plans/` matches this branch | No plan file for the branch |

Print the detection result before running any gate.

### Phase 2 — lint/type/build (always when applicable) — `n/a — composite logic only`

Run, in order, the detected commands:

- Node: `npm run typecheck` (if exists) → `npm run lint` (if exists) → `npm run build` (if exists)
- Rust: `cargo check` → `cargo clippy -- -D warnings`
- Python: `ruff check .` (if installed) → `mypy .` (if config exists)
- Go: `go vet ./...` → `gofmt -l .`

Capture stdout/stderr per command. Emit `PASS` if exit 0, `FAIL` with first 5 error lines
otherwise.

### Phase 2b — schema drift (conditional) — composite logic only

Only if a server ORM was detected. A model/schema change committed without its migration ships a broken release that no test or lint catches.
- **Node/Prisma** (<project-a>): `npx prisma migrate status` → `FAIL` on "pending migrations" (list names); `PASS` on "up to date".
- **Django**: `python manage.py makemigrations --check --dry-run` → `FAIL` if changes detected.
- **SQLAlchemy/Alembic**: `alembic current` vs `alembic heads` → `FAIL` if they differ.

Client-side stores are NOT migration targets — Dexie/IndexedDB (Figurinhas) `SKIP` here; its drift mode is the `update()`-no-op gotcha, caught by tests, not migrations.

Skip with `(skipped: no server ORM detected)`.

### Phase 2c — scope consistency (conditional) — composite logic only

Only if a plan under `.claude/plans/` matches this branch. Catches silent scope creep AND silent scope reduction between plan and delivery.
- Read the plan's `## Scope` / `## Phases`; diff `git diff origin/<base>...HEAD --name-only` against it.
- `FAIL` if files outside the planned modules were touched (creep) OR a planned phase has zero touched files (silent drop).
- A mid-stream change the user explicitly approved → mark `(user-approved)` and pass.

Skip with `(skipped: no plan file for this branch)`.

### Phase 3: tests (always when applicable), inline

Run the FULL test suite (targeted-first applies to quick mode only). Detected test commands:
- Node: `npm test --silent` (prefers `pnpm test` if `pnpm-lock.yaml` exists)
- Rust: `cargo test --quiet`
- Python: `pytest -q`
- Go: `go test ./... -count=1`

Emit `PASS`/`FAIL` with failing-test names on fail.

### Phase 4 — coverage (conditional) — invoke `coverage-gap`

Only if Phase 1 detected coverage config. Invoke `coverage-gap` skill (which reads
the threshold and computes the gap). Emit `PASS` if at or above threshold, `FAIL`
with the gap percentage otherwise.

Skip with `(skipped: no coverage threshold configured)` if not applicable.

### Phase 5 — sonar-check (conditional) — invoke `sonar-check`

Only if `sonar-project.properties` exists. Invoke `sonar-check` skill (pre-push
SonarCloud preflight: scans for S5852/S5144/coverage gaps).

Skip with `(skipped: no sonar-project.properties)` if not applicable.

### Phase 6: gh-fix-ci (conditional), invoke `gh-fix-ci` in report-only mode

Only if a PR exists for the current branch. A green run on the same SHA marks this gate `PASS (ci@<sha>)` but does not skip any other gate. Invoke `gh-fix-ci` in **report-only mode**
(watch and triage, no edits, no pushes: this composite is read-only). Emit `PASS` if all
required checks are green, `FAIL` if any required check failed, `PENDING` if any required check
is still running. Pending is not green.

Skip with `(skipped: no open PR for this branch)` if not applicable.

### Phase 7 — sentry quick-scan (conditional) — invoke `sentry`

Only if Sentry configured. Query Sentry for new issues in the last 24h tagged with
this branch's release (if `--release` known) or this repo's project. Emit `PASS` if
no new issues with `level: error` or higher, `WARN` with issue count otherwise.

Skip with `(skipped: no Sentry DSN configured)` if not applicable.

### Phase 8 — Reconciliation (always)

Emit the gate matrix (see Reconciliation block below).

## Reconciliation block

```
VERIFY BEFORE DONE — <repo> @ <branch> @ <short-sha>

Gate matrix
| Gate         | Verdict | Detail | Status |
| ------------ | ------- | ------ | ------ |
| lint/type    | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| build        | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| tests        | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| schema-drift | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| scope        | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| coverage     | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| sonar        | <PASS|FAIL|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| gh-fix-ci    | <PASS|FAIL|PENDING|SKIP> | <one-line> | <✅ DONE|🚧 BLOCKED|🚫 DECLINED> |
| sentry       | <PASS|WARN|SKIP> | <one-line> | <✅ DONE|⚠️ DONE_WITH_CONCERNS|🚫 DECLINED> |

Verdict: <READY-TO-SHIP | NOT-READY | NEEDS-ATTENTION> ✅ DONE
Blockers (in priority order):
  1. <gate>: <what to do>
  2. ...
Recommended next skill: <e.g., /gh-fix-ci or /ship or /merge-confidently>
Snapshot:        (none — verify-before-done is a gate, not a write)
Open watch:      (none) | <future-dated obligation>
```

Verdict rules:
- **READY-TO-SHIP** — all applicable gates `PASS` (skips don't disqualify)
- **NEEDS-ATTENTION** — at least one `WARN` (sentry), no `FAIL`
- **NOT-READY** — any `FAIL`

## Stop conditions

- **--strict mode** + any `SKIP` → emit `NEEDS-ATTENTION` and recommend resolving
  the skip (e.g., "no test runner detected — add one or pass `--skip tests`")
- **Build hangs >5 minutes** → emit `FAIL` with `(timeout)`
- **Test hangs >10 minutes** → emit `FAIL` with `(timeout)`
- **CI check pending >15 minutes** → emit `PENDING` (not FAIL); recommend re-running
  the composite later or invoking `gh-fix-ci` directly
- **Non-trivial decision detected in changes** (>1 module touched, >150 LOC, or
  asserting compiler-unverifiable behavior) → before emitting `READY-TO-SHIP`,
  suggest the operator run the `decision-discipline.md` 5-step scaffold on the
  leading uncertainty. Do not block on it — this is a prompt, not a gate.

## Negative rules

- Do NOT auto-fix gate failures (both modes). This skill is read-only, it only reports.
- Do NOT skip Phase 2 (lint/type/build) on the basis of "tests will catch it" — they
  often don't catch type errors or compile errors.
- Do NOT trust a `SKIP` as `PASS`. A skipped gate means "not applicable" not "passing".
- Do NOT emit `READY-TO-SHIP` with even one `FAIL` — verdict logic above is binding.
- Do NOT run any gate that the user passed via `--skip`. Honor the override but mark
  it `SKIP (user-override)` so the trail is visible.

## Configuration

Optional repo-local `.claude/verify-before-done.json`:

```json
{
  "strict_mode": false,
  "skip": [],
  "timeouts": {
    "build_seconds": 300,
    "test_seconds": 600,
    "ci_pending_seconds": 900
  },
  "test_command_override": null,
  "build_command_override": null
}
```

## Outputs / Evidence

- Per-gate captured logs at `~/.claude/state/verify-before-done/<repo>/<timestamp>/`
- Gate matrix (printed)
- Verdict line (parseable: `Verdict: READY-TO-SHIP` etc.)

## Integration

- **Pairs with `/ship`**: `/ship` step 1 runs `/verify-before-done quick`, which returns
  `PASS` / `FAIL` / `PARTIAL`; `/ship` proceeds only on `PASS` (or acknowledged `PARTIAL`).
  Use full mode (`READY-TO-SHIP` / `NOT-READY` / `NEEDS-ATTENTION`) for a stricter pre-release gate
- **Pairs with `/merge-confidently`** — runs as a stricter pre-merge gate
- **Pairs with release-please** — runs on `main` before the pending release PR is merged
- **Inverse of `/gh-fix-ci`**: verify reports failures (and calls gh-fix-ci in report-only mode); gh-fix-ci in fix mode repairs them

## Related skills

- `ship` — actually performs the merge/tag/release; this skill is the gate
- `pr-merge-readiness` — broader PR-level readiness (CI + reviews + conflicts); this
  skill is narrower (local + remote quality gates only)
- `gh-fix-ci`, `coverage-gap`, `sonar-check`, `sentry`: atomic skills called per gate
