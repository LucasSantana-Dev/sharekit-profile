# Required Checks for Merge

Before any PR can merge, ALL must pass. This is the source of truth for `/pr-merge-readiness` Phase 1.

## Checks (gating merge)

1. **CI green** — all required workflows in `.github/workflows/` pass
2. **Approval** — at least one approving review OR repo's branch protection minimum
3. **No unresolved threads** — CodeRabbit, Greptile, Sonar, human reviewers all done
4. **No merge conflicts** with base branch
5. **Base branch up-to-date** — either branch is current or rebase-on-merge configured
6. **Correct base branch** (release-branch repos only) — base is `release`, not `main` (except `/hotfix` and `chore/release-vX.Y.Z`)
7. **Regression test present** (hotfixes only) — severity gate documented in PR body

See `standards/pr-conventions.md §82–96` for full detail.

## Merge method

- **Default:** squash (one PR = one commit)
- **Exception 1:** `/release-cut`'s `chore/release-vX.Y.Z` PR — use merge commit
- **Exception 2:** PR explicitly documented as merge-commit intent in body (rare)
- **Never:** rebase-merge unless branch protection requires it

Forbidden: `gh pr merge --admin`, `gh api ... rulesets` mutations (blocked at PreToolUse).
