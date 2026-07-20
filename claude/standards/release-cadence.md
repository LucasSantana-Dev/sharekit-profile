# Release Cadence

How repos under this account ship. Applies to any repo that has a long-lived
`release` branch on origin. For direct-to-main repos, see `pr-conventions.md`
section "Direct-to-main".

## Model

```
feature branch  →  /pr-to-release  →  release (batched, no tags)
                                       │
                                       ├─ /dep-sweep adds bot PRs to the batch
                                       │
                                       ▼
                                  /release-cut  →  main + tag vX.Y.Z + GitHub release
                                       ▲
                                       │ cherry-pick back from /hotfix
                                       │
                          /hotfix  →  main + tag vX.Y.(Z+1)   ⚠ emergency only
```

`release` is the integration target. `main` is the released history. A version
exists if and only if it's a tag on `main`.

## When to cut a release

A `/release-cut` is appropriate when ANY of these holds:

- `git rev-list --count main..release` ≥ 5 (default threshold, configurable
  per repo in `.claude/release-cadence-config.json`)
- A user-visible feature is complete and the user wants it shipped now
- Two weeks have passed since the last cut (drift nudge)
- Pre-deploy verification window has cleared (no incidents, CI green on
  release HEAD)

A `/release-cut` is NOT appropriate when:

- Only one PR has landed on release (batch of 1 defeats the purpose)
- CI on the release HEAD is red
- An open `/hotfix` is in progress on main (cut after it lands and is
  cherry-picked)

## Version selection (semver)

`/release-cut` Phase 2 decides patch/minor/major from the commits in
`main..release`:

| Commit prefix / footer        | Version bump |
|-------------------------------|--------------|
| `feat:` / `feat(scope):`      | minor        |
| `fix:` / `perf:` / `refactor:`| patch        |
| `BREAKING CHANGE:` footer     | major        |
| `chore:` / `docs:` / `test:`  | no bump alone, but bundles with above |
| Pre-1.0 anything              | minor        |

If the commits don't follow conventional format, fall back to: human-reviewable
diff size + the user's call. The composite must surface the proposed version
before pushing the tag.

## Hotfix policy

`/hotfix` is the ONLY acceptable bypass of the release branch. Required:

- Production-degraded OR actively-exploited vuln OR customer-blocking with
  no workaround
- Smallest possible change (no drive-by refactors, no dep bumps)
- Regression test that fails on pre-hotfix HEAD
- Cherry-pick back to release as Phase 10 of `/hotfix`
- `/incident-response` Phase 3 (post-mortem) queued automatically afterwards (ADR + memory)

"Small fix that someone wants in prod today" is NOT a hotfix. That's a
`/pr-to-release` + an early `/release-cut`.

## Bot PR handling

Dependabot / Renovate / pre-commit-ci PRs go through `/dep-sweep`, never
through `/pr-to-release` individually. The sweep buckets them:

- AUTO-MERGE: devDeps, patch bumps, lockfile-only — squash-merged to release
- REVIEW: minors, security advisories, sensitive packages — surfaced
- HOLD: majors, framework upgrades — left for manual handling

Bot PRs collapse into one CHANGELOG line under `[Unreleased]`:
`Deps: bumped <n> packages (see commit log for details)`.

## Cleanup expectations

After each `/release-cut`:
- The tagged version's branch (`chore/release-vX.Y.Z`) is deleted
- Source branches of PRs included in the cut are deleted (the composite
  does this in Phase 9)
- `/branch-hygiene` runs periodically to catch what slipped through

## Configuration

Per-repo overrides live at `.claude/release-cadence-config.json`:

```json
{
  "release_branch": "release",
  "main_branch": "main",
  "drift_threshold_commits": 5,
  "drift_threshold_days": 14,
  "conventional_commits_required": false,
  "auto_deploy_on_tag": false
}
```

Defaults apply when missing. `/release-cut` and the
`main-release-drift-nudge` hook both read this file.

## Anti-patterns this standard explicitly rejects

- Cutting a version for every PR (the original problem this whole model fixed)
- Force-pushing to `release` or `main`
- Using `gh pr merge --admin` to bypass branch protection
- Editing the CHANGELOG at version-cut time — `/pr-to-release` already
  appended the lines; `/release-cut` only renames `[Unreleased]` to the
  version
- Tagging from a working directory that doesn't match origin/main HEAD
- Skipping the regression test on a `/hotfix` because "the fix is obvious"
