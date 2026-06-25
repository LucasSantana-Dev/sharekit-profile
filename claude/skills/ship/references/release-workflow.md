# Release Workflow

The `/ship` skill handles both merge + release scenarios. This doc covers release-specific gates and flow.

## Release gates (when to NOT cut)

A `/release-cut` is NOT appropriate when:

- Only one PR on release (defeats batching purpose)
- CI on release HEAD is red
- An open `/hotfix` is in progress on main
- More than 14 days since last cut with no verified demand (drift-nudge applies)

See `standards/release-cadence.md §25–41` for full policy.

## Version selection (semver)

From commits in `main..release`:

| Commit prefix / footer        | Version bump |
|-------------------------------|--------------|
| `feat:` / `feat(scope):`      | minor        |
| `fix:` / `perf:` / `refactor:`| patch        |
| `BREAKING CHANGE:` footer     | major        |
| `chore:` / `docs:` / `test:`  | no bump alone |

If commits don't follow conventional format: human-review the diff + ask user.
`/release-cut` Phase 2 surfaces the proposed version before tagging.

## Post-release cleanup

After each `/release-cut`:
- Tagged version branch (`chore/release-vX.Y.Z`) deleted
- Source branches of merged PRs deleted (composite handles Phase 9)
- `/branch-hygiene` runs periodically to catch stragglers

## Hotfix exception

`/hotfix` is the ONLY bypass of release branch. Required:

- Production-degraded OR actively-exploited vuln OR customer-blocking with no workaround
- Smallest possible change (no drive-by refactors)
- Regression test that fails on pre-hotfix HEAD
- Cherry-pick back to release as Phase 10
- `/incident-response` Phase 3 (post-mortem) queued automatically

"Small fix that someone wants in prod today" is NOT a hotfix — that's `/pr-to-release` + early `/release-cut`.

See `standards/release-cadence.md §60–72` for full policy.
