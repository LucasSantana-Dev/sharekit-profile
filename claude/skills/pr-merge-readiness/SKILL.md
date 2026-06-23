---
name: pr-merge-readiness
description: >
  Aggregate CI, reviews, conflicts, branch staleness, and third-party checks
  (CodeRabbit, Sonar, Greptile, Socket) into a single MERGE / WAIT / FIX verdict.
  Use when about to merge a PR, triaging a batch of PRs, or evaluating third-party
  review comments. Replaces manual checklist of "is CI green, reviews approved,
  conflicts present, branch stale, bots satisfied?"
user-invocable: true
argument-hint: "[<PR number or URL>] [--strict]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/pr-merge-readiness
---

# PR Merge Readiness

Collect every signal that gates a PR merge into one verdict: **MERGE**, **WAIT**,
or **FIX**. Signal-first output: verdict + top-3 findings inline; full catalog
in references.

## Use When

- About to merge a PR: one-call readiness check instead of manual ci-watch,
  review scan, conflict check
- Triaging a batch of PRs: tabulate readiness across multiple PRs
- Reviewing third-party comments: aggregate CodeRabbit/Greptile/Sonar feedback
  into the merge gate

## Do Not Use When

- PR is WIP (use `/ship` later; if not yet open, use `/pr-flow` first)
- Only one signal matters (use `/ci-watch` for CI-only, `gh pr checks` for
  specific check)

## Inputs / Prerequisites

- `gh` CLI authenticated for the repo
- PR number, URL, or current branch (defaults to current branch's PR)
- Optional: `--strict` flag (any `WARN` → `FAIL`)

---

## Workflow

### Step 1: Identify the PR

Fetch PR metadata once (number, author, branch, draft state, merge status).

```bash
PR=$(gh pr view --json number -q .number 2>/dev/null)
[ -z "$PR" ] && { echo "No open PR for current branch"; exit 1; }
[ -n "$1" ] && PR="$1"
```

Done when: PR number validated and metadata fetched.

### Step 2: Collect signals (8 checks)

Run all signals in parallel. See `references/signals-catalog.md` for each
signal's command, status rules, and verdict table.

Signals:
1. Draft state (`PASS` / `FAIL`)
2. Mergeability + conflicts (`PASS` / `WARN` / `FAIL`)
3. CI status (`PASS` / `WARN` / `FAIL`)
4. Review decision (`PASS` / `WARN` / `FAIL` / `SKIP`)
5. Branch staleness vs. base (`PASS` / `WARN` / `FAIL`)
6. Third-party comments (CodeRabbit, Greptile, Sonar, Socket)
   (`PASS` / `WARN` / `FAIL` / `SKIP`)
7. PR size (`PASS` / `WARN` / `FAIL` in strict mode)
8. Branch age since last update (`PASS` / `WARN`)

Done when: all 8 signals have a status.

### Step 3: Compute verdict

Aggregate per `signals-catalog.md`:

| Condition | Verdict |
|---|---|
| Any `FAIL` | **FIX** |
| Any `WARN` (no FAIL) | **WAIT** |
| All `PASS`/`SKIP` | **MERGE** |

In `--strict` mode: any `WARN` → `FAIL` → verdict becomes **FIX**.

Done when: single verdict determined.

### Step 4: Output report (signal-first)

Lead with verdict + top-3 findings. Full examples in `references/output-patterns.md`.

For **MERGE**: ready now; suggest `gh pr merge <PR> --squash --delete-branch`.

For **WAIT**: list warnings (e.g., "CodeRabbit has 2 unresolved suggestions");
merge is possible but warnings should be addressed first. Suggest `/gh-address-comments`.

For **FIX**: list failures (e.g., "CI failing on test-backend", "merge conflicts
in 2 files"); do not merge. Suggest `/gh-fix-ci` or manual rebase.

On network error: mark that signal as `WARN` ("could not check"); continue;
never silently treat unknown as `PASS`.

Done when: user sees verdict + can take next action immediately.

---

## Hard Rules (Safety)

1. **Never automate merge on another person's PR or one with comments from
   another human.** HALT and report. See
   `standards/decisions/2026-05-28-cross-tool-hard-rule-parity.md`.
   (Bots like Dependabot, CodeRabbit do not count as "another person".)

2. **gh not authenticated or PR invalid**: report and stop. Do not continue.

3. **Network failure on any signal**: mark as `WARN` ("could not check"),
   continue. Never silently upgrade unknown to PASS.

---

## Stop / Failure Conditions

- `gh` not authenticated → `exit 1` with message
- PR not found / invalid number → `exit 1` with message
- Repo not found → `exit 1` with message

---

## Outputs

- Single-line verdict: **MERGE** / **WAIT** / **FIX**
- Per-signal status (✓ / ⚠ / ✗) with brief reasoning
- Top-3 findings inline; full detail gated ("ask for full list" or in reference)
- Suggested next skill / `gh` command to advance (e.g., `/gh-address-comments`,
  `/gh-fix-ci`, `git rebase main`, `gh pr merge ...`)
- Does NOT merge — that remains an explicit user action

---

## Related Standards

- `standards/pr-conventions.md` — PR naming, commit format, merge method, reviewer
  behavior
- `standards/decisions/2026-05-28-cross-tool-hard-rule-parity.md` — "never automate
  on another person's PR" hard rule

## Related Skills

- `/ci-watch` — if only CI status matters
- `/gh-address-comments` — resolve third-party reviewer feedback
- `/gh-fix-ci` — diagnose + fix failing checks
- `/merge-confidently` — direct-to-main repos (no `release` branch)
- `/pr-flow` — create a PR before merging
