# Red Flags: Observable Violations

Anti-actions an agent must never execute or approve. Each entry gives the observed trigger and the required action: halt, surface, and fix before continuing. Referenced from skills, standards, and incident workflows.

## Git / Release Domain

### Force-Push to main / Protected Branch
Trigger: `git push --force` (or `--force-with-lease`) to main; `gh pr merge --admin` on a PR with failing CI or incomplete reviews; rebase/reset of main after it reached origin; branch protection changed via API mid-session.
Action: never do it. Halt and ask the human (T3).

---

### Merging a PR with Failing CI
Trigger: red, incomplete, or skipped check; green faked via `--no-verify`, a check removed from the required list, or a skip decorator.
Action: never merge. Fix or surface the failing check first.

---

### Committing a Secret / .env File
Trigger: `.env`, `*.key`, `credentials.json`, `secret*`, API keys, tokens, DB URIs, private keys, or PII staged or committed; missing `.gitignore` entry for a secret file.
Action: halt, unstage, rotate the secret (commits cannot be undone), add the ignore entry.

---

### Pushing to main Without PR
Trigger: direct push to `main`; commit with no PR link; merge commit on main with no PR number.
Action: never push to main directly, except repos listed in `push-exemptions.txt` (see pr-conventions.md). Open a PR.

---

### Auto-Merge or Auto-Deploy Without Clear CI/Review State
Trigger: merge or deploy while CI is pending, unknown, or not queried; speed cited to skip review-thread or required-check state; deploy justified by a prior deploy.
Action: halt. Unclear state means risk was never assessed. Verify this change before merging or deploying.

---

### Tag / Release Pushed Without Gate
Trigger: tag pushed without a version bump commit or changelog update; semver violated; release cut from a branch other than `release/*` or `main`.
Action: do not tag. Run the `changelog-update --bump` gate first.

---

## Security Domain

### Editing ~/.claude-env in Place Without Committing
Trigger: `~/.claude-env` standards, skills, or settings modified or drifted with no matching commit.
Action: commit the change before acting on it (rules are code; changes must be auditable).

---

### Skipping Hook / Verification
Trigger: `--no-verify`, `HUSKY=0` on logic changes (allowed only for comment/formatting fixes), hook bypassed via env var, signing disabled (`commit.gpgsign=false`) mid-session.
Action: never bypass. Fix the failing gate instead.

---

### Writing Passwords or Keys to stdout / Logs
Trigger: output, logs, tests, or errors showing `password:`, `api_key:`, `token:`, `secret:` with a value.
Action: never print credential material. Redact, and rotate if exposed.

---

## Testing Domain

### Skipping Tests Then Claiming Done
Trigger: fix commit with no test added or changed; tests disabled (`skip`, `.skip`, `@pytest.mark.skip`); coverage dropped and called "unrelated"; test run omitted before commit.
Action: add or run the tests before claiming done.

---

### Test Coverage Decrease Without Justification
Trigger: coverage drops >5% in the diff; new files at 0%; tests removed without replacement; gate passed by lowering the baseline.
Action: restore coverage or justify explicitly; never lower the baseline to pass.

---

### Flaky Test Not Fixed, Marked Skip
Trigger: `@skip`, `@flaky`, or `pending` on a flaky test with no root-cause work; "known issue, skipping for now".
Action: investigate and fix the root cause; do not skip.

---

## Harness Integrity Domain

### Reporting a Metric Without Running the Gate
Trigger: coverage, tests-pass, lint-clean, or performance claimed without running the tool.
Action: run the gate, then report its output.

---

### Composite Skill Bail-Out Without Surfacing Blocker
Trigger: a composite silently switches to a sub-skill, moves on from an incomplete phase, or reports success with earlier phases skipped.
Action: do not bail mid-composite. Surface the blocker as the composite's output.

---

### Writing File Without State-Check (Idempotency Violation)
Trigger: file edited twice with no intervening read; append to a file a parallel agent may have changed; same line changed twice with different content.
Action: state-check (re-read) before every mutation.

---

### Agent Edits Repository Context Without Committing First
Trigger: CLAUDE.md, an ADR, or a standard modified but uncommitted; agent acts on context not yet in the repository.
Action: commit the context first (repository is the source of truth).

---

### Runtime Residue Mistaken for Durable Policy
Trigger: a behavior exists only as a session temp file, env var, or in-memory state; a fix applied to a rendered file (e.g. `~/.claude/settings.json`) but not its tracked source (`~/.claude-env/settings/shared.json`), so a render reverts it.
Action: land the change in the committed standard, skill, hook, or tracked source.

---

### Duplicate Skill/Hook Names Create Routing Ambiguity
Trigger: two skills or hooks share a name across `.archive/` and live catalogs, or across `~/.agents/skills` and a project-local `claude/skills/`; routing picks the wrong one.
Action: surface the duplicate and resolve to one canonical entry; never silently use the stale or archived one.

---

### Hook Trying to Do Too Much
Trigger: one hook script handles unrelated responsibilities (detection, logging, blocking, notification); one branch throwing silently disables the rest.
Action: split into single-purpose hooks.

---

## Claims Honesty Domain

### Claiming Done Because the Git Tree Is Clean
Trigger: "complete" asserted from a clean `git status` without re-reading the requirement; a revert or no-op commit looks identical to a fix.
Action: verify the diff against the request before claiming done.

---

### Claiming Feature "Done" Without Integration Test
Trigger: PR ready with no E2E test; feature claimed with no test exercising the flow; "works in isolation" conflated with "works in product".
Action: add or run an integration test before claiming done.

---

### Reporting Success When Work Was Partially Done
Trigger: "done" with follow-up work still listed; "all issues resolved" while referenced issues are open; task closed while continuation steps remain.
Action: report the remaining work explicitly; never mark partial work done.

---

### Claiming No Regressions Without Running Regression Test
Trigger: "no regressions", "safe", or "backward compatible" stated without the full suite, integration tests, or old-API coverage; rollback risk unassessed.
Action: run the tests before the claim, or state it is unverified.

---

### Modifying Acceptance Criteria to Match Incomplete Implementation
Trigger: task list changed from the original issue; assertions loosened (`>=` for `===`); edge case dropped mid-implementation; "done when" reworded to match what was built.
Action: never change criteria post-hoc. Meet them or surface the gap to the owner.

---

## Cross-Domain Patterns

### Observable Violation: Stuck Loop Without Escalation
Signal: same task attempted >2 times; same failing command retried 3+ times unchanged; blocker surfaced but work continues; success claimed despite unsurfaced blockers.
Action: state "Stuck: [task], [attempt N], [blocker]", switch approach; after 2 switches, escalate.

---

### Observable Violation: Context Compression Without Commitment
Signal: `/compact` before task completion; handoff drafted but not saved to `~/.claude/handoffs/`; findings discarded instead of logged to memory, ADR, or task file.
Action: write a durable checkpoint before compressing or ending the session.

---

## How to Use This Standard

1. Skills cite specific flags in `hard-rules` (e.g. `/merge-confidently`: "Merging PR with failing CI").
2. Use as a pre-merge checklist in code review.
3. After a failure, identify the crossed flag and add a prevention rule to the ADR.
4. `/skill-effectiveness-audit` scans session logs monthly for violations.

## Related Standards

`workflow.md` (includes durable execution), `security.md`, `testing.md`, `claims-honesty.md` (if exists).
