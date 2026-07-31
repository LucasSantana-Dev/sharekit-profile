---
name: pr-merge-readiness
description: Aggregate every signal that gates a PR merge (CI, reviews, conflicts, branch staleness, security scans, third-party reviewers like CodeRabbit/Greptile/Sonar) into a single readiness verdict — MERGE / WAIT / FIX. Use as the one-call check before clicking merge instead of running ci-watch + gh-fix-ci + manual scan.
user-invocable: true
argument-hint: "[<PR number or URL>] [--strict]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/pr-merge-readiness
invocation_type: internal
triggers:
  - pr ready
  - merge check
  - is this pr ready
  - merge readiness
---

# PR Merge Readiness

Replaces the manual checklist of "is CI green? are reviews approved? does it conflict?
did Sonar/CodeRabbit/Greptile finish? is the branch stale?" with a single skill that
collects every signal and outputs one verdict.

## Use When

- About to merge a PR and want one combined "ready / not ready" answer
- Reviewing many PRs in a batch and need a triage table
- Reviewing PRs from PR-Agent, CodeRabbit, or Greptile that already have third-party
  comments to reconcile

## Do Not Use When

- The PR is still WIP and you know it isn't done — use `ship` later
- Only one signal matters (e.g., just need CI status) — use `ci-watch` directly
- The work is on a branch with no PR yet — use `pr-flow` to create one first

## Inputs / Prereqs

- `gh` CLI authenticated for the repo
- PR number, URL, or current branch (defaults to current branch's open PR)
- `--strict` flag: fail on any non-passing signal, even informational ones

---

## Workflow

### 1. Identify the PR

```bash
# Default to current branch's PR
PR=$(gh pr view --json number -q .number 2>/dev/null)
[ -z "$PR" ] && { echo "No open PR for current branch"; exit 1; }

# Or use explicit arg
[ -n "$1" ] && PR="$1"

gh pr view "$PR" --json title,headRefName,baseRefName,mergeable,mergeStateStatus,\
isDraft,reviewDecision,statusCheckRollup,labels,additions,deletions,changedFiles,\
updatedAt,author,url
```

### 2. Collect signals

Run all checks in parallel where possible. Each produces a status: `PASS`, `WARN`, `FAIL`,
or `SKIP` (signal not applicable to this repo).

#### Signal 1: Draft state
```bash
gh pr view "$PR" --json isDraft -q .isDraft
```
Draft → `FAIL` (cannot merge a draft).

#### Signal 2: Mergeability and conflicts
```bash
gh pr view "$PR" --json mergeable,mergeStateStatus
```
`mergeable: CONFLICTING` → `FAIL` with the list of conflicting files.
`mergeStateStatus: BLOCKED` → `FAIL` (required reviews missing or branch protection).
`mergeStateStatus: BEHIND` → `WARN` (rebase/merge main needed).
`mergeStateStatus: CLEAN` → `PASS`.

#### Signal 3: CI status
```bash
gh pr checks "$PR" --json name,state,conclusion,detailsUrl
```
Any `FAILURE` → `FAIL` with the failing check names.
Any `IN_PROGRESS`/`PENDING` → `WARN` ("CI still running").
All `SUCCESS` → `PASS`.

For known-flaky-but-not-blocking checks, classify as `WARN` not `FAIL` (configurable
per-repo via `.claude/pr-checks-allow-flaky.txt` if present).

#### Signal 4: Review decision
```bash
gh pr view "$PR" --json reviewDecision,reviewRequests
```
`APPROVED` → `PASS`.
`CHANGES_REQUESTED` → `FAIL` with reviewer names.
`REVIEW_REQUIRED` → `WARN` ("awaiting review from X").
No required reviewers → `SKIP`.

#### Signal 5: Branch staleness
```bash
gh pr view "$PR" --json baseRefName,headRefName
git fetch origin --quiet
BEHIND=$(git rev-list --count "origin/$(gh pr view "$PR" --json headRefName -q .headRefName)..origin/$(gh pr view "$PR" --json baseRefName -q .baseRefName)" 2>/dev/null)
```
Branch >50 commits behind base → `WARN` ("rebase recommended").
Branch >200 commits behind → `FAIL` ("rebase required, very stale").

#### Signal 6: Third-party reviewer comments

Detect which third-party reviewers exist on the repo and check each:

```bash
# All review comments
gh pr view "$PR" --json comments -q '.comments[] | {author: .author.login, body: .body[0:200]}'

# CodeRabbit
gh pr view "$PR" --json comments -q '.comments[] | select(.author.login == "coderabbitai") | .body' | head -20

# Greptile
gh pr view "$PR" --json comments -q '.comments[] | select(.author.login | startswith("greptile")) | .body' | head -20

# Sonar (status check, not comment)
gh pr checks "$PR" --json name,state,conclusion -q '.[] | select(.name | test("Sonar"; "i"))'

# Socket
gh pr checks "$PR" --json name,state,conclusion -q '.[] | select(.name | test("Socket"; "i"))'
```

For each found reviewer:
- Unaddressed `🛑` / "must fix" / "blocking" comments → `FAIL`
- Unaddressed suggestions / nits → `WARN`
- All resolved or only positive comments → `PASS`
- Reviewer not present on this repo → `SKIP`

#### Signal 7: PR size
```bash
gh pr view "$PR" --json additions,deletions,changedFiles
```
- <300 LOC, <10 files → `PASS`
- 300–1000 LOC or 10–25 files → `WARN` ("large — verify scope")
- >1000 LOC or >25 files → `FAIL` in `--strict` mode, `WARN` otherwise

#### Signal 8: Branch age
```bash
gh pr view "$PR" --json createdAt,updatedAt
```
Last update >7 days ago → `WARN` ("stale; rebase + re-verify before merge").

#### Signal 9: Card/issue fidelity

"Does this PR know which card it closes, and is that card's state still consistent with
what's actually being merged?" — added 2026-07-25 (Phase 3, card/prototype-fidelity debate).
Catches the same class of drift as <project-b>'s board-hygiene bug: a card claims one state,
the repo says another.

```bash
gh pr view "$PR" --json body,closingIssuesReferences -q '{body: .body, linked: [.closingIssuesReferences[]?.number]}'
```

- No `closingIssuesReferences` AND PR body has no `Closes #`/`Fixes #`/`Resolves #` pattern
  → `SKIP` ("no linked card — untracked PRs are a normal pattern on this developer's repos,
  not a defect; don't WARN small/solo/dep-bump/typo PRs that never had a card to begin with")
- Linked issue found but already `CLOSED` independent of this PR (check
  `gh issue view <N> --json state,closedAt`, then confirm closure provenance via the
  issue timeline (`mergeStateStatus` is current PR mergeability state, not a closing
  event, so never use it as provenance):
  `gh api repos/{owner}/{repo}/issues/<N>/timeline --jq '.[] | select(.event=="closed") | {actor: .actor.login, commit_id}'`;
  a closing actor/commit unrelated to this PR means independent closure) → `WARN`
  ("linked issue #N already closed by something else: verify this PR still matches
  its current state before merging, board-hygiene drift risk")
- Linked issue found and `OPEN` → `PASS`
- Repo doesn't use issues for this workflow (no issues enabled) → `SKIP`

This signal only checks PR-to-card *linkage and state consistency* — it does not check
whether the diff matches the card's described scope (over/under-building). That's
`overengineering-auditor`'s job (its `abstraction`/`generalization` categories cover
over-scoped commits); route there for scope-content review, not here.

---

### 3. Compute verdict

Aggregate the signals:

| Condition | Verdict |
|---|---|
| Any `FAIL` | **FIX** — list the failing signals; do not merge |
| Any `WARN` (no FAIL) | **WAIT** — list warnings; merge possible but explain why first |
| All `PASS` or `SKIP` | **MERGE** — ready |

In `--strict` mode, any `WARN` becomes `FAIL`.

### 4. Output the report

```
PR #1234 — <title>
Branch: feature/x → main  |  Author: @lucas  |  Updated: 2h ago

SIGNALS
  ✓ Not draft
  ✓ Mergeable (clean)
  ✓ CI: 12/12 checks passing
  ✓ Reviews: APPROVED by @reviewer
  ✓ Branch: 3 commits behind base
  ⚠ CodeRabbit: 2 unresolved suggestions
  ✓ PR size: 287 LOC, 8 files
  ✓ Branch age: updated 2h ago
  ✓ Card fidelity: linked issue #42 (open)

VERDICT: WAIT
Reason: CodeRabbit has 2 unresolved suggestions. Resolve or explicitly dismiss
before merging. Run `/gh-address-comments` to handle them.

Suggested next action:
  /gh-address-comments  (then re-run this skill)
```

For `MERGE`:
```
VERDICT: MERGE
Suggested next action:
  gh pr merge 1234 --squash --delete-branch
```

For `FIX`:
```
VERDICT: FIX
Reason: CI check "test (backend)" is failing. Fix the failing test before merging.

Suggested next action:
  /gh-fix-ci  (or open the failing run: <detailsUrl>)
```

---

## Outputs / Evidence

- One-page verdict (MERGE / WAIT / FIX)
- Per-signal status with actionable detail
- Suggested next skill or `gh` command to advance
- Does not actually merge — that remains an explicit user action

## Failure / Stop Conditions

- `gh` not authenticated → report and stop
- Repo not found / PR number invalid → report and stop
- Network failure on any signal → mark that signal as `WARN` ("could not check") and
  continue; never silently treat unknown as PASS

## Memory Hooks

- Read memory for any per-repo overrides (allow-flaky checks, third-party reviewer
  expectations) before computing the verdict
- Optional: write a one-line memory after a MERGE verdict was acted on, so trend data
  ("<project-a> merged 12 PRs this week, 3 with WARN overridden") becomes available
