# Release Cadence

How repos under this account ship. Default since 2026-07-23: trunk-based
development on `main`, with release-please owning versioning. The long-lived
`release`-branch release-train is RETIRED (1-of-12 adoption falsified the
model) — it survives only as an explicitly opted-in per-repo exception, and
no repo currently opts in.

## Model

```
feature branch  →  /pr-to-release (or /merge-confidently)  →  main
                                                                │
                                                                ▼
                                          release-please (GitHub Action, per repo)
                                          keeps an always-open release PR:
                                          changelog + version bump
                                                                │
                                                                ▼
                                  merge release PR  →  tag vX.Y.Z + GitHub Release
                                                                ▲
                                                                │
                          /hotfix  →  main (`fix:` commit)   ⚠ emergency only
                          (release-please folds it into the pending release PR)
```

`main` is both the integration target and the released history. A version
exists if and only if it's a tag on `main`, created by release-please.

## release-please as the versioning mechanism

release-please runs as a GitHub Action in each repo. It:

- Watches conventional commits landing on `main`
- Maintains an always-open release PR that bumps the version and promotes
  `[Unreleased]` changelog content into the new version's section
- On merge of that PR: creates tag `vX.Y.Z` and the GitHub Release

Manual version selection, manual changelog promotion, and manual tagging are
retired in release-please repos. `/version-bump` and `/changelog-update`
remain only for repos WITHOUT release-please configured.

## When a release happens

The user merges the release PR. Good moments:

- A user-visible feature has landed and should ship now
- The release PR has accumulated ≥5 conventional commits (drift nudge)
- Pre-deploy verification window has cleared (CI green on `main`)

Do not merge the release PR when:

- CI on the release PR is red
- An open `/hotfix` is in flight on `main` (merge the hotfix first; the
  release PR regenerates automatically)

## Version selection (semver)

release-please derives patch/minor/major from conventional commits on `main`:

| Commit prefix / footer        | Version bump |
|-------------------------------|--------------|
| `feat:` / `feat(scope):`      | minor        |
| `fix:` / `perf:` / `refactor:`| patch        |
| `BREAKING CHANGE:` footer / `!` after type | major |
| `chore:` / `docs:` / `test:`  | no bump alone, but bundles with above |
| Pre-1.0 anything              | minor        |

If commits don't follow conventional format, release-please can't infer the
bump — keep commits conventional. That is the whole game.

## Hotfix policy

`/hotfix` branches from `main` and merges back to `main` with a `fix:`
commit; release-please folds it into the pending release PR. If the fix
cannot wait for the next release, merge the release PR immediately after the
hotfix — it becomes a patch release. Required:

- Production-degraded OR actively-exploited vuln OR customer-blocking with
  no workaround
- Smallest possible change (no drive-by refactors, no dep bumps)
- Regression test that fails on pre-hotfix HEAD
- `/incident-response` Phase 3 (post-mortem) queued automatically afterwards (ADR + memory)

"Small fix that someone wants in prod today" is NOT a hotfix. That's a normal
`fix:` PR to `main` plus merging the pending release PR.

## Bot PR handling

Dependabot / Renovate / pre-commit-ci PRs go through `/dep-sweep`, never
through `/pr-to-release` individually, targeted at the configured base
branch (`main` by default; a repo's opted-in `release_branch` under the
Exception below, otherwise). Bucket definitions (AUTO-MERGE / REVIEW / HOLD,
including the security-advisories-always-HOLD precedence rule) live in
`/dep-sweep`'s own risk-classification table — not restated here, to avoid
the two drifting out of sync with each other.

In release-please repos, bot commits land as `chore(deps):` lines in the
generated release PR — no manual `[Unreleased]` bookkeeping. `/dep-sweep`
detects this and skips its own changelog-append phase accordingly.

## Cleanup expectations

After each release PR merge:
- Source branches of PRs included are deleted (GitHub auto-delete covers most)
- `/branch-hygiene` runs periodically to catch what slipped through

## Exception: opted-in `release` branch

A repo MAY explicitly opt back into the retired release-train by recording it
in `.claude/release-cadence-config.json`:

```json
{
  "model": "release-train",
  "release_branch": "release",
  "main_branch": "main",
  "drift_threshold_commits": 5,
  "drift_threshold_days": 14,
  "conventional_commits_required": false,
  "auto_deploy_on_tag": false
}
```

No repo currently opts in. The historical train flow is preserved under a
RETIRED banner in `/release-cut` for reference. Do not enable the train for a
repo without an explicit user decision; the old `main-release-drift-nudge`
hook is retired with it.

## Anti-patterns this standard explicitly rejects

- Cutting a version for every PR (the original problem; release-please
  batching fixes it)
- Re-creating a `release` branch without recording the opt-in
- Force-pushing to `main`
- Using `gh pr merge --admin` to bypass branch protection
- Hand-editing the release PR's changelog instead of fixing the underlying
  conventional commits
- Tagging from a working directory that doesn't match origin/main HEAD
- Skipping the regression test on a `/hotfix` because "the fix is obvious"
