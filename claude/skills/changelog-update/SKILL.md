---
name: changelog-update
description: "Update CHANGELOG.md (Keep a Changelog): promote [Unreleased] to a versioned section. --bump also infers semver, syncs monorepo versions, refreshes lockfiles and opens the release-prep PR. For repos without release-please."
argument-hint: '[--bump [X.Y.Z] [--entry "<line>"] | --append "<line>"]'
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/changelog-update
triggers:
  - changelog
  - update changelog
  - promote unreleased
  - changelog update
  - version bump
  - bump version
  - semver
---

# Changelog Update Skill

Maintains CHANGELOG.md (Keep a Changelog) and, with `--bump`, prepares the whole
release as a PR: version inference, version files, lockfile, changelog promotion.
Absorbs the retired `version-bump` skill.

> **Scope note (2026-07-23):** in release-please repos (the default), release-please owns changelog promotion, version bump, and tag via its release PR. Do not run the promote or `--bump` flow there. This skill remains for repos without release-please configured, and `/merge-confidently --open` still uses its append-only mode for `[Unreleased]` entries in those repos.

## Modes

| Invocation | Does |
|---|---|
| `/changelog-update` | Default: promote `[Unreleased]` to `[NEW_VERSION]`, bump the root package version, sync the VERSION constant. Local edits, then branch + PR (Step 7). |
| `/changelog-update --bump [X.Y.Z] [--entry "<line>"]` | Full release prep: infer (or take) the version, bump every workspace package, refresh lockfile, promote the changelog, open the PR. `--entry` first writes one line under `[Unreleased]` on the bump branch. See "Bump mode". |
| `/changelog-update --append "<line>"` | Append-only: one line under `[Unreleased]` with a Keep a Changelog category (Added/Changed/Fixed/Removed/Security/Deprecated). No version change, no promotion, no tag. Commits on the current branch (never `main`). Stop if the exact line already exists. Used by `merge-confidently --open`. |

Default mode: if the root `package.json` has a `workspaces` field, or several `package.json` files exist under `packages/`, it behaves as `--bump` (all packages kept in sync). Say so in the reply.

## Hard gates (apply to both modes)

- Never push to `main`/`master`. Never create or push a tag. Changes go through a branch + PR. Tagging and GitHub Release creation belong to `ship-it --from tag`.
- Never merge directly and never use `gh pr merge --admin`. Arm auto-merge only when the repo allows it (`gh repo view --json autoMergeAllowed -q .autoMergeAllowed` is `true`): `gh pr merge --auto --squash`. If `false`, leave the PR open and report it.
- Never force-push. Push with `git push origin <branch>` only.
- Stop if the working tree is dirty, if `[Unreleased]` is empty (and the version is not already promoted; waived when `--entry` supplies the line), or if tag `vX.Y.Z` or `X.Y.Z` already exists locally or on origin.
- Idempotency: before `git switch -c chore/bump-X.Y.Z`, run `gh pr list --head chore/bump-X.Y.Z --state open`. Reuse that PR only if it is self-authored with no comments from another person; otherwise halt and tell the user. If the run produces no file changes, report "already done, skipping" and make no empty commit.
- Never promote twice: if `## [X.Y.Z]` already exists in CHANGELOG.md, skip promotion, keep going with the version files and PR.
- Stop and revert the version change if build or tests fail after the bump.

## When to Use

- Cutting a release in a repo without release-please
- `[Unreleased]` has accumulated significant work
- CHANGELOG is stale relative to git tags
- A caller (`ship-it`, `hotfix`) needs a bump PR

## Workflow (default mode)

### Step 1: Gather context

```bash
REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
CURRENT_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
LATEST_TAG=$(git describe --tags --abbrev=0)
UNRELEASED_COMMITS=$(git log ${LATEST_TAG}..HEAD --oneline | wc -l | tr -d ' ')

echo "Package version: $CURRENT_VERSION"
echo "Latest tag:      $LATEST_TAG"
echo "Commits since:   $UNRELEASED_COMMITS"
git status --porcelain   # must be empty
head -20 CHANGELOG.md
```

### Step 2: Determine bump type

From commits since the last tag:
- `BREAKING CHANGE` in a body or `!` after the type: **major**
- any `feat`: **minor**
- otherwise (`fix`, `chore`, `docs`, `test`, `refactor`): **patch**

```bash
git log ${LATEST_TAG}..HEAD --format="%s" | python3 -c "
import sys, re
msgs = sys.stdin.readlines()
breaking = any(re.match(r'^\w+(\([^)]*\))?!:', m) or 'BREAKING' in m for m in msgs)
has_feat = any(re.match(r'^feat[\(!:]', m) for m in msgs)
print('major' if breaking else 'minor' if has_feat else 'patch')
"
```

### Step 3: Compute the new version

```bash
python3 -c "
import re
parts = list(map(int, re.match(r'(\d+)\.(\d+)\.(\d+)', '${CURRENT_VERSION}').groups()))
bump = '${BUMP_TYPE}'
if bump == 'major': parts = [parts[0]+1, 0, 0]
elif bump == 'minor': parts = [parts[0], parts[1]+1, 0]
else: parts[2] += 1
print('.'.join(map(str, parts)))
"
```

Validate any user-supplied version against `^\d+\.\d+\.\d+(-[\w.]+)?$` (not `2.7`).

### Step 4: Promote [Unreleased] to [NEW_VERSION]

Guard: if `## [NEW_VERSION]` already exists, skip this step (hard gate).

1. Keep `## [Unreleased]` at the top, empty, for future work
2. Insert `## [NEW_VERSION] - YYYY-MM-DD` (today) below it
3. Move the old `[Unreleased]` content under the new heading

```markdown
## [Unreleased]

## [1.12.0] - 2026-03-15

### Added
- <feature description>

### Fixed
- <bug fix description>
```

### Step 5: Bump package.json

```bash
npm version ${NEW_VERSION} --no-git-tag-version
```

### Step 6: Sync VERSION constant (Forge Space repos only)

```bash
if [ -f src/index.ts ] && grep -q "export const VERSION" src/index.ts; then
  sed -i.bak "s/export const VERSION = '[0-9]*\.[0-9]*\.[0-9]*';/export const VERSION = '${NEW_VERSION}';/" src/index.ts
  rm -f src/index.ts.bak
fi
```

### Step 7: Validate, branch, commit, PR

```bash
npm run build && npm test && npm run validate   # use the repo's own gates

git switch -c chore/bump-${NEW_VERSION}
git add $(ls CHANGELOG.md package.json package-lock.json src/index.ts 2>/dev/null)   # only files that exist
git commit -m "chore: bump version to ${NEW_VERSION}"
git push origin chore/bump-${NEW_VERSION}
gh pr create --title "chore: bump version to ${NEW_VERSION}" --body "<summary from CHANGELOG>"
# only if autoMergeAllowed is true:
gh pr merge --auto --squash
```

There is no tag or release step here. After the bump PR merges, run
`/ship-it --from tag` (passing the bump merge SHA) to tag, create the GitHub
Release and deploy.

## Bump mode (`--bump [X.Y.Z]`)

Everything in the default workflow, plus the monorepo and release-prep duties
below. The version is the argument when given, else inferred in Steps 2 and 3
and stated in the reply. A caller that already computed the version (for example
`hotfix` with a patch bump) passes it explicitly.

Prerequisites: git repo clean on `main`/`master`, `CHANGELOG.md` with an
`[Unreleased]` section (or an already promoted `[X.Y.Z]`), `gh` installed and
authenticated.

1. **Validate**: version matches semver; `git status --porcelain` empty; `git tag -l "v${NEW_VERSION}" "${NEW_VERSION}"` empty; and `git ls-remote --exit-code --tags origin refs/tags/v${NEW_VERSION}` exits 2 (absent; exit 0 means the tag exists on origin). Otherwise stop and suggest the next free version or `ship-it`. Run the open-PR idempotency check from the hard gates.
2. **Bump every version file in sync**: root `package.json` and every workspace package (`packages/*/package.json`, or the paths in the root `workspaces` field) to `NEW_VERSION`. Prefer `jq` or `npm version ${NEW_VERSION} --workspaces --include-workspace-root --no-git-tag-version`. Update internal cross-dependency ranges only when they pin the old exact version. Also sync `pyproject.toml` and the VERSION constant where present.
3. **Refresh the lockfile**: `npm install --package-lock-only` (or the repo's package manager equivalent) so `package-lock.json` matches the new versions. Stage it.
4. **Promote CHANGELOG**: Step 4 above. If `[NEW_VERSION]` is already promoted (earlier attempt), skip promotion only; still bump versions and open the PR. Never create a duplicate heading or re-move content.
5. **Branch and commit**: `--bump` cuts `chore/bump-NEW_VERSION` itself (callers must not cut their own branch). With `--entry "<line>"`, first write that line under `[Unreleased]` (with a category) on this branch, so promotion picks it up. Note: anything already in `[Unreleased]` ships with this version. Message `chore: bump version to NEW_VERSION`.
6. **Push and open the PR**: `git push origin chore/bump-NEW_VERSION`, then `gh pr create`. Check `autoMergeAllowed`: `true` means `gh pr merge --auto --squash` (`--auto-merge` is not a `gh pr create` flag); `false` means leave the PR open and report it. Never merge directly.
7. **Report**: chosen version and why (the commit types that drove it), every file updated, whether the changelog was promoted or skipped, the PR link and auto-merge status. If PR creation fails, the user can delete the branch; nothing else was touched.

`--bump` never tags. Callers (`ship-it`, `hotfix`) wait for the bump PR to merge,
then run `ship-it --from tag`.

## Append mode (`--append "<line>"`)

1. Refuse on `main`/`master`; require a clean tree.
2. If CHANGELOG.md already contains the exact line, stop ("already done, skipping").
3. Add the line under the right `### <category>` inside `## [Unreleased]` (create the category if missing). Do not touch versions or other sections.
4. Commit on the current branch as `docs(changelog): record <subject>`. No push, tag or PR here; the caller (`merge-confidently --open`) pushes.

## CHANGELOG Format Rules

Follow **Keep a Changelog** (https://keepachangelog.com):

```markdown
## [Unreleased]

## [1.12.0] - 2026-03-15

### Added
- **Feature name** - Description of what was added.

### Fixed
- **Bug name** - What was wrong and how it was fixed.

### Changed
- **What changed** - Old behavior to new behavior.

### Removed
- **What was removed** - And why.

### Security
- **CVE-YYYY-XXXX** - Vulnerability description and fix.
```

**Rules:**
- Use `### Added`, `### Fixed`, `### Changed`, `### Removed`, `### Security`
- Bold the feature/fix name; use a hyphen before the description
- Most recent version at the top (after `[Unreleased]`)
- Include PR/issue references where meaningful: `(#123)`
- Write for a human reader, not a git log dump
- `[Unreleased]` stays EMPTY after a release

## Version Alignment Checklist

- [ ] Root and all workspace `package.json` versions match the new version
- [ ] Lockfile refreshed
- [ ] `src/index.ts` VERSION constant matches (Forge Space core only)
- [ ] CHANGELOG has the new version entry, `[Unreleased]` empty
- [ ] Work is on a branch with an open PR, not on `main`
- [ ] No tag created (left to `ship-it --from tag`)

## Forge Space Repo Specifics

| Repo | VERSION constant location |
|------|--------------------------|
| core | `src/index.ts`: `export const VERSION = '...'` |
| siza-gen | `package.json` only |
| ui-mcp | `package.json` only |
| mcp-gateway | `pyproject.toml` (Python) + `package.json` |
| siza | `package.json` only |

## Outputs / Evidence

Return: new version string, CHANGELOG diff summary, files bumped, PR link with
auto-merge status, and confirmation that build/tests pass after the bump.

## Memory Hooks

- Read `project_overview` for current version and test counts before writing
- Write a `project_overview` update after the release ships with the new version
