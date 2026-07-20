# PR Conventions

Shared rules for any PR opened from this account, regardless of which composite
creates it (`/pr-to-release`, `/hotfix`, `/dep-sweep`,
`/repo-bootstrap`, `/release-cut`, `/pr-flow`).

## Branch naming

`<type>/<short-slug>` where `<type>` is one of:

- `feat/<slug>` — new functionality
- `fix/<slug>` — bug repair, no behavior change beyond the fix
- `chore/<slug>` — tooling, config, deps, non-user-visible
- `docs/<slug>` — docs-only
- `refactor/<slug>` — code reshape, no behavior change
- `hotfix/<slug>` — emergency, branched from main not release
- `chore/release-vX.Y.Z` — release-cut PR (machine-generated)
- `chore/repo-bootstrap` — bootstrap PR (machine-generated)
- `deps/<batch-date>` — `/dep-sweep` batched bumps

Slugs are kebab-case, ≤40 chars. No issue numbers in the slug — they go in
the PR body. No dates in the slug except for `deps/<batch-date>`.

## Commit messages (conventional commits)

Squash-merged PRs use the PR title as the commit subject; non-squash merges
require every commit on the branch to follow conventional-commits format:

```
<type>(<scope>)?: <subject>

<body — what + why, not how>

<footer — Closes #, BREAKING CHANGE:, Co-Authored-By:>
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `perf`, `test`, `build`,
`ci`, `style`, `revert`.

Subject rules:
- ≤72 chars, imperative mood, no trailing period
- Don't repeat the type in the subject (`fix: fix the bug` is bad)
- Mention the user-visible effect, not the file changed

`BREAKING CHANGE:` footer triggers a major version bump at the next
`/release-cut`. Use sparingly; prefer additive changes with deprecation
warnings.

## PR title

For release-branch repos: `<type>: <subject>` matching the squash commit.
For direct-to-main repos: same. No `[WIP]` prefixes — use Draft state instead.

## PR body (template)

Every composite-opened PR includes:

```
## What
<one or two paragraphs of user-visible effect>

## Why
<context, link to issue or incident>

## How
<implementation notes only if non-obvious; otherwise omit>

## Risk
<what could break, how it was mitigated; for /hotfix include blast radius>

## Tests
<what was added or why none was needed>

## Changelog
<exact line that will land in CHANGELOG.md [Unreleased] section>
```

The `Changelog` field is the source of truth for what `/pr-to-release`
appends. Omitting it triggers a refusal from `/pr-to-release` Phase 6 — no
silent CHANGELOG entries.

## Required checks (gating merge)

Every PR must pass before merge:

1. CI green (all required workflows defined in `.github/workflows/`)
2. At least one approving review OR repo's branch protection minimum
3. No unresolved threads from CodeRabbit / Greptile / Sonar / human reviewers
4. No merge conflicts with base
5. Branch is up-to-date with base (or rebase-on-merge is configured)
6. For release-branch repos: base is `release`, not `main` (except `/hotfix`
   and `chore/release-vX.Y.Z`)
7. For `/hotfix`: severity gate documented in PR body, regression test present

`/pr-merge-readiness` aggregates all of these into a single MERGE / WAIT / FIX
verdict. Use it before clicking merge.

## Merge method

- Default: squash (one PR = one commit on the integration branch)
- Exception 1: `/release-cut`'s `chore/release-vX.Y.Z` PR — use merge commit
  to preserve the release branch's history
- Exception 2: PRs explicitly opened with merge-commit intent (rare; document
  in PR body why)
- Never rebase-merge unless the repo's `branch protection` requires it

`gh pr merge --admin` is forbidden. The `gh api ... rulesets` mutation is
forbidden. Both are blocked at the `PreToolUse` hook layer.

## Reviewer behavior

When reviewing your own composite-opened PR:
- Read the diff, not just the description — composites can drift from intent
- Verify CHANGELOG line matches the actual change
- For `/dep-sweep`: spot-check at least one auto-merged PR before approving
- For `/hotfix`: confirm severity gate text in PR body matches reality
- For `/release-cut`: confirm proposed version against `main..release` diff

## Stale PR policy

PRs sit at most 14 days open before `/branch-hygiene` flags them. The
remediation depends on state:

- Approved + green CI + no conflicts → composite re-prompts to merge
- Conflicts → composite re-prompts to rebase or close
- Red CI → composite re-prompts to fix or close
- No activity from author/reviewer → composite leaves a comment + flags
  for the next session

`/branch-hygiene` deletes the remote branch only after the PR is merged or
closed, never while it's open.

## Direct-to-main repos (no `release` branch)

For repos without a `release` branch (single-developer, internal tools, or
explicitly trunk-based):
- `/merge-confidently` replaces `/pr-to-release`
- `/ship-it` replaces `/release-cut`
- Everything else in this standard still applies

The router detects which model the repo uses via `git ls-remote --heads
origin release`. Composites should not be invoked manually against the wrong
model — the router prevents it.
