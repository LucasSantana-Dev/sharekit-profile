# Red Flags: Observable Violations

A concise catalogue of anti-actions an agent must never execute or approve. Each entry names the violation, gives the observable signal, and grounds why it matters. Organized by domain. Reference this from skills, standards, and incident-response workflows.

## Git / Release Domain

### Force-Push to main / Protected Branch
**Observable signal:**
- `git push --force origin main` (or `--force-with-lease`)
- `gh pr merge --admin` on a PR with failing CI or incomplete reviews
- Rebase/reset on main after commit reaches origin
- Branch protection enforcement state changed via API mid-session

**Why it matters:** Rewrites history; loses commits, loses audit trail, breaks other operators' branches.

---

### Merging a PR with Failing CI
**Observable signal:**
- PR status shows red (failing check)
- CI job marked as incomplete or skipped
- Merge button used when `enforce_admins: true` is not in place
- Green badge faked via skip/bypass (`--no-verify`, removed check from required list, skip decorator in config)

**Why it matters:** Ships unverified code; breaks trunk; increases incident blast radius.

---

### Committing a Secret / .env File
**Observable signal:**
- File matches: `.env`, `*.key`, `credentials.json`, `secret*`, `PASSWORD=`, API key, OAuth token, database URI in plain text
- File staged or committed with PII (email in plaintext outside comments, phone, SSN, account numbers)
- Git history diff shows `aws_access_key`, `OPENAI_API_KEY`, private SSH key material
- `.gitignore` missing entry that should block a secret file

**Why it matters:** Exposes credentials; enables account takeover, data breach, unauthorized API usage. Commits cannot be undone; secret must be rotated.

---

### Pushing to main Without PR
**Observable signal:**
- Direct push to `main` branch (bypasses code review)
- Commit message missing from PR body / code review log
- No corresponding PR link in commit or git log
- History shows "Merge commit" to main with no PR number

**Why it matters:** Removes peer review; loses change rationale; violates trunk discipline.

---

### Tag / Release Pushed Without Gate
**Observable signal:**
- `git tag` created and pushed without version bump commit
- Release artifact tagged but changelog not updated
- Semantic versioning violated (e.g., tag v1.2.2 then v1.2.1 added later)
- Release cut while branch is not `release/*` or `main`

**Why it matters:** Breaks dependency resolution; users cannot pin stable versions; rollback is confusing.

---

## Security Domain

### Editing ~/.claude-env in Place Without Committing
**Observable signal:**
- `~/.claude-env/standards/*.md` modified but not committed
- `~/.claude-env/skills/*.md` or `SKILL.yaml` changed without corresponding commit message
- `~/.claude-env/settings.json` or `settings.local.json` drift detected vs. last committed version
- Agent skill edits visible in session but not in git log

**Why it matters:** Rules are code; changes must be auditable. Next session gets outdated context; durable decisions are lost.

---

### Skipping Hook / Verification
**Observable signal:**
- Commit with `--no-verify` flag
- `HUSKY=0` used for non-trivial changes (allowed only for comment/formatting fixes, not logic)
- Pre-commit hook bypassed via env var while committing code
- Git config changed to disable signing (`commit.gpgsign=false`) mid-session

**Why it matters:** Hooks enforce quality gates (lint, test, secret-scan, commit-msg). Bypassing them ships unverified changes.

---

### Writing Passwords or Keys to stdout / Logs
**Observable signal:**
- Output contains `password:`, `api_key:`, `token:`, `secret:` followed by a value
- Echo or print statement reveals credential material
- Log file captured with credentials visible
- Test output or error message leaks authentication data

**Why it matters:** Credentials exposed in logs; reviewers, watchers, CI systems see secret material.

---

## Testing Domain

### Skipping Tests Then Claiming Done
**Observable signal:**
- `git commit -m "fix: ..."` with no corresponding test file created or modified
- Test suite commented out or disabled (`skip()`, `x.test()`, `.skip`, `@pytest.mark.skip`)
- Coverage report shows decrease after change; claim is "not related"
- `--no-test` flag used or test invocation omitted before commit

**Why it matters:** Untested code breaks silently; regression not caught; claims honesty is violated.

---

### Test Coverage Decrease Without Justification
**Observable signal:**
- Coverage drops >5% in diff
- New files added with 0% coverage
- Old tests removed without replacement
- Coverage gate passed via baseline lowering, not code quality

**Why it matters:** Debt accumulates; future changes become riskier.

---

### Flaky Test Not Fixed, Marked Skip
**Observable signal:**
- Test in CI shows `@skip`, `@flaky`, or `pending` marker
- Flake history exists but no root-cause investigation or fix committed
- Same test fails intermittently across runs; agent marks it skip instead of fixing
- Flake logged as "known issue — skipping for now"

**Why it matters:** Unreliable tests mask real failures; credibility of test suite erodes.

---

## Harness Integrity Domain

### Reporting a Metric Without Running the Gate
**Observable signal:**
- Claim "coverage is 85%" without running `npm run coverage` or equivalent
- "All tests pass" claimed without running test suite
- "No lint errors" stated without running linter
- Performance metric cited without running benchmark

**Why it matters:** Unverified claims; operator decisions based on false data.

---

### Composite Skill Bail-Out Without Surfacing Blocker
**Observable signal:**
- Skill invoked (e.g., `/refactor-pipeline`) starts a phase but silently switches to a sub-skill
- Phase output shows "moving to next phase" but prior phase was incomplete
- Composite completes "successfully" but earlier phases logged as skipped
- Agent output claims "refactored and tested" but reconciliation block for "test" phase shows incomplete

**Why it matters:** Contract violation; composite guarantees (chaining, gate enforcement) are broken. Next session has no record of where it failed.

---

### Writing File Without State-Check (Idempotency Violation)
**Observable signal:**
- File edited twice in same session with no intervening read
- Append operation runs on file that may have been modified by parallel agent
- Git diff shows same line changed twice with different content
- Timestamp on file shows recent modification but no session record of why

**Why it matters:** Double-mutations; state drift; data loss.

---

### Agent Edits Repository Context Without Committing First
**Observable signal:**
- CLAUDE.md modified but not committed
- ADR added but not in git log
- New standard in `~/.claude-env/standards/` without corresponding commit
- Agent acts on context that is not yet in repository (violates "repository as single source of truth")

**Why it matters:** Future agents act on outdated rules; decisions are not durable; handoffs are incomplete.

---

## Claims Honesty Domain

### Claiming Feature "Done" Without Integration Test
**Observable signal:**
- PR marked as "ready for merge" with no E2E test added
- Feature claim: "user can log in" but no test that exercises login flow end-to-end
- Change marked complete but downstream integration point untested
- "Works in isolation" vs. "works in product" conflated

**Why it matters:** Feature appears done but breaks in real usage; user-facing regression.

---

### Reporting Success When Work Was Partially Done
**Observable signal:**
- Handoff marked "done" but follow-up work listed in same task file
- Skill output says "completed" but next action is evident in code
- PR claim: "all issues resolved" but 2 of 3 referenced issues still open
- Session close marks task complete but CLAUDE.md lists continuation steps

**Why it matters:** Operator believes work is done; next session re-discovers same incomplete state.

---

### Claiming No Regressions Without Running Regression Test
**Observable signal:**
- "No regressions" stated without running full test suite
- Change marked "safe" without running integration tests
- Claim: "backward compatible" but no test covering old API behavior
- Rollback risk not assessed but claim is "low risk"

**Why it matters:** Unverified safety claim; operator confidence is unjustified.

---

### Modifying Acceptance Criteria to Match Incomplete Implementation
**Observable signal:**
- PR description task list changed from original issue
- Test assertions loosened to pass (e.g., `>=` instead of `===`)
- Edge case requirement removed from spec mid-implementation
- "Done when" criterion reworded to match what was built instead of what was requested

**Why it matters:** Acceptance criteria are contractual; changing them post-hoc violates trust.

---

## Cross-Domain Patterns

### Observable Violation: Stuck Loop Without Escalation
**Signal:**
- Same task attempted >2 times; agent continues attempting without surface escalation
- Bash command fails; agent retries same command 3+ times without change
- Blocker surfaced in session but work continues as if blocker doesn't exist
- Final output claims success despite unsurfaced blockers

**Why it matters:** Wastes session budget; blocks the operator from making a decision; violates "stuck protocol."

---

### Observable Violation: Context Compression Without Commitment
**Signal:**
- `/compact` used before completing a task
- Handoff drafted but not saved to `~/.claude/handoffs/`
- Intermediate findings discarded instead of logged to memory / ADR / task file
- Session wraps without durable checkpoint

**Why it matters:** Context is lost; next session restarts from scratch; accumulated decisions are erased.

---

## How to Use This Standard

1. **Skill enforcement:** Reference specific red flags in skill YAML `hard-rules` sections (e.g., `/ship` skill lists "Red flag: Merging PR with failing CI").
2. **Code review checkpoints:** Use red-flag list as a pre-merge checklist — agents reviewing PRs should scan this list.
3. **Incident post-mortems:** After a failure, check which red flag was crossed; add prevention rule to ADR.
4. **Session audits:** `/skill-effectiveness-audit` runs monthly and scans session logs for red-flag violations; queues offending agents/skills for review.

---

## Related Standards

- `standards/workflow.md` — trunk-based discipline, branch protection
- `standards/security.md` — secret handling, input validation
- `standards/testing.md` — test coverage expectations
- `standards/durable-execution.md` — idempotency, state checkpoints
- `standards/claims-honesty.md` (if exists) — verification gates for operator claims