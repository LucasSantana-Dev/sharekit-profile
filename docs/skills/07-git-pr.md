# Git & PR Workflow Skills

`pr-flow` for opening a PR from a branch; `pr-to-release` (composite) for the full merge cycle including CI and CodeRabbit. `pr-merge-readiness` gives a single MERGE/WAIT/FIX verdict. `gh-fix-ci` when checks are red.

---

## /pr-flow

Create a branch, commit changes, push them, and open a PR in one coordinated flow.

**Phases:**
1. Create branch (or use existing)
2. Commit staged changes with message
3. Push to remote
4. Open PR with title + body
5. Verify PR created

**When to use:** Ready to submit work for review

**Output:** Open PR with link

---

## /pr-to-release ⭐⭐ **Composite**

Take a working branch to merged-into-release: pr-flow → readiness → CodeRabbit → CI → changelog → merge.

**Phases:**
1. Create PR (pr-flow)
2. Check merge readiness (MERGE/WAIT/FIX verdict)
3. Let CodeRabbit review
4. Monitor CI until green
5. Promote unreleased changes to CHANGELOG
6. Merge to release branch

**When to use:** Branch ready → merged → release

**Output:** Merged PR on release branch

---

## /pr-merge-readiness

Aggregate every signal that gates a PR merge into a single MERGE / WAIT / FIX verdict.

**Signals:**
- All CI checks pass
- Sonar quality gate passes
- Coverage thresholds met
- No failing review comments
- All conversations resolved
- Approvals (if required)

**When to use:** Before merge; verify all gates ready

**Output:** MERGE / WAIT (waiting for X) / FIX (blocker Y)

---

## /pr-snapshot

Show status table for multiple PRs in one batch API call with color indicators.

**Shows:**
- PR title + author
- CI status (pass/fail/pending)
- Review status (approved/changes-requested/pending)
- Coverage change
- Days open

**When to use:** Quick PR overview (daily or when checking status)

**Output:** Status table with color indicators

---

## /merge-confidently ⭐ **Composite**

Take a PR from "I think it's ready" to merged: readiness → fix blockers → address comments → ship.

**Phases:**
1. Check merge readiness
2. Address reviewer comments (if blocked)
3. Fix failing CI checks
4. Merge when all signals green

**When to use:** "I think it's ready" but not 100% sure

**Output:** Merged PR

---

## /gh-address-comments

Address review comments on the open GitHub PR for the current branch.

**Process:**
1. Fetch all review comments
2. Analyze each comment (suggestion, question, blocker)
3. Implement fixes / answer questions
4. Push changes to PR
5. Mark conversations resolved

**When to use:** Review received; need to address comments

**Output:** Updated PR with comments addressed

---

## /gh-fix-ci

Debug and fix failing GitHub PR checks.

**Process:**
1. Fetch Actions logs
2. Identify failing step
3. Query repo CI history for similar failures
4. Propose fix
5. Implement + push to PR
6. Monitor until checks pass

**When to use:** PR checks red; need root-cause + fix

**Output:** Fixed CI + passing checks

---

## /gh-cli

GitHub CLI (`gh`) for common repository, issue, and PR operations.

**Operations:**
- Create/list/view issues
- Create/list/view PRs
- Add labels/assignees/reviewers
- Merge PR
- View Actions logs

**When to use:** GitHub operations needed; CLI preferred over web UI

**Output:** GitHub operation result

---

## /unstick-pr

Recover a PR whose head SHA disagrees with its branch ref (webhook desync).

**When to use:** PR shows "cannot merge" due to SHA mismatch

**Process:**
1. Identify current head SHA
2. Force-push branch to correct SHA
3. Verify PR updates
4. Retry merge

**Output:** Recovered PR ready for merge

---

## /force-merge-self-pr

Merge your own PR through a protected branch when self-approval is impossible.

**When to use:** Your PR, no other reviewers available, protected branch requires approval

**Gating:** Hard check — only your own PR (not others'), no human comments

**Output:** Force-merged PR

---

## /branch-hygiene ⭐ **Composite**

One-pass cleanup of stale local branches, dead worktrees, merged branches, and abandoned remote PR branches.

**Phases:**
1. Delete merged local branches
2. Delete abandoned remote PR branches (merged into main)
3. Remove dead worktrees
4. Verify clean state

**When to use:** Branches accumulating; need cleanup

**Output:** Clean branch state

---

## /using-git-worktrees

Create isolated git worktrees for feature work that should not reuse the main checkout.

**When to use:** Parallel feature work; avoid context switching in main checkout

**Creates:** New worktree at `/Volumes/External HD/Desenvolvimento/.worktrees/<task>/`

**Output:** New worktree ready for work

---

## /adt-worktree-flow

Decide when and how to use git worktrees for isolated parallel work.

**Decisions:**
- Single task: reuse main checkout
- 2+ parallel tasks same repo: worktrees required
- Different repos: independent clones

**Output:** Worktree strategy for current work

---

## /adt-checkpoint

Git-level WIP safety net. Stashes uncommitted work, tags, and pushes to remote.

**When to use:** Before risky operations, context switch, or end of day

**Process:**
1. Stash uncommitted changes
2. Create WIP tag
3. Push to remote
4. Log checkpoint

**Output:** Stashed state + recovery instructions

---

## /first-pr ⭐ **Composite**

Land a safe first PR in an unfamiliar repo: onboard → context-pack → scope → TDD → PR.

**Phases:**
1. Rapid repo intake (tools, patterns, expectations)
2. Build task-aware context bundle
3. Scope the contribution
4. Write test first (TDD)
5. Implement + open PR

**When to use:** First PR in unfamiliar repo

**Output:** Safe, well-scoped first PR

---

**Last updated:** 2026-06-25
