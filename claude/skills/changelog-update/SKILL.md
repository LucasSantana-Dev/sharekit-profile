---
name: changelog-update
description: Updates CHANGELOG.md from recent commits, grouping entries by type (feat/fix/docs/breaking) with semantic version headings.
  Update CHANGELOG.md by promoting [Unreleased] content to a versioned section
  and bumping the package version. Follows Keep a Changelog format. Use when
  preparing a release or when [Unreleased] has accumulated work that needs to
  be captured under a version.
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/changelog-update
triggers:
  - changelog
  - update changelog
  - promote unreleased
  - changelog update
---

# Changelog Update Skill

Automates the CHANGELOG.md maintenance cycle for Forge Space repos (and any
project following Keep a Changelog format).

## When to Use

- Cutting a new release (patch, minor, or major)
- `[Unreleased]` has accumulated significant work
- CHANGELOG is stale relative to git tags
- After merging a batch of PRs that should be versioned together

## Workflow

### Step 1 — Gather context

```bash
# Current state
REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
CURRENT_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
LATEST_TAG=$(git tag --sort=-version:refname | head -1)
UNRELEASED_COMMITS=$(git log ${LATEST_TAG}..main --oneline | wc -l | tr -d ' ')

echo "Package version: $CURRENT_VERSION"
echo "Latest tag:      $LATEST_TAG"
echo "Commits since:   $UNRELEASED_COMMITS"

# Check [Unreleased] section size
grep -c "^-\s" CHANGELOG.md && echo "bullet points in CHANGELOG"

# Check version alignment
head -5 CHANGELOG.md
```

### Step 2 — Determine version bump type

Based on the commits since the last tag:
- `feat:` or `feat!:` present → **minor** (or **major** if breaking)
- Only `fix:`, `chore:`, `docs:`, `test:`, `refactor:` → **patch**
- `BREAKING CHANGE` in body or `!` after type → **major**

```bash
# Auto-detect bump type from commits
git log ${LATEST_TAG}..main --format="%s" | python3 -c "
import sys, re
msgs = sys.stdin.readlines()
breaking = any('!' in m.split(':')[0] or 'BREAKING' in m for m in msgs)
has_feat = any(re.match(r'^feat[\(!:]', m) for m in msgs)
print('major' if breaking else 'minor' if has_feat else 'patch')
"
```

### Step 3 — Compute new version

```bash
# Compute new version from current package.json
python3 -c "
import re, sys
version = '${CURRENT_VERSION}'
parts = list(map(int, re.match(r'(\d+)\.(\d+)\.(\d+)', version).groups()))
bump = '${BUMP_TYPE}'  # from step 2
if bump == 'major': parts[0]+=1; parts[1]=0; parts[2]=0
elif bump == 'minor': parts[1]+=1; parts[2]=0
else: parts[2]+=1
print('.'.join(map(str, parts)))
"
```

### Step 4 — Promote [Unreleased] → [NEW_VERSION]

Edit `CHANGELOG.md`:

1. Keep `## [Unreleased]` header at the top (for future work)
2. Add blank line after it
3. Insert `## [NEW_VERSION] - YYYY-MM-DD`
4. Move all content from the old `[Unreleased]` section under the new version

**Template structure:**

```markdown
## [Unreleased]

## [1.12.0] - 2026-03-15

### Added
- <feature description>

### Fixed
- <bug fix description>

### Changed
- <change description>

## [1.11.2] - 2026-03-15
...
```

### Step 5 — Bump package.json version

```bash
npm version ${NEW_VERSION} --no-git-tag-version
```

### Step 6 — Sync VERSION constant (Forge Space repos only)

```bash
# core repo: src/index.ts has a VERSION constant
if [ -f src/index.ts ] && grep -q "export const VERSION" src/index.ts; then
  sed -i.bak "s/export const VERSION = '[0-9]*\.[0-9]*\.[0-9]*';/export const VERSION = '${NEW_VERSION}';/" src/index.ts
  rm -f src/index.ts.bak
  echo "VERSION constant synced to ${NEW_VERSION}"
fi
```

### Step 7 — Validate and commit

```bash
# Run full validation
npm run build && npm test && npm run validate

# Commit
git add CHANGELOG.md package.json package-lock.json src/index.ts
git commit -m "chore(release): v${NEW_VERSION} — <one-line summary>

CHANGELOG:
- [${NEW_VERSION}]: <summary of what changed>
"
```

### Step 8 — Create tag + GitHub Release

```bash
git tag "v${NEW_VERSION}"
git push && git push --tags

# Create GitHub Release
gh release create "v${NEW_VERSION}" \
  --repo "$REPO" \
  --title "v${NEW_VERSION} — <summary>" \
  --notes "<release notes from CHANGELOG>" \
  --target main
```

## CHANGELOG Format Rules

Follow **Keep a Changelog** (https://keepachangelog.com):

```markdown
## [Unreleased]

## [1.12.0] - 2026-03-15

### Added
- **Feature name** — Description of what was added.

### Fixed
- **Bug name** — What was wrong and how it was fixed.

### Changed
- **What changed** — Old behavior → new behavior.

### Removed
- **What was removed** — And why.

### Security
- **CVE-YYYY-XXXX** — Vulnerability description and fix.
```

**Rules:**
- Use `### Added`, `### Fixed`, `### Changed`, `### Removed`, `### Security`
- Bold the feature/fix name; use `—` separator before description
- Most recent version at the top (after `[Unreleased]`)
- Include PR/issue references where meaningful: `(#123)`
- Write for a human reader, not a git log dump
- `[Unreleased]` section stays EMPTY after a release (ready for next cycle)

## Version Alignment Checklist

After bumping:
- [ ] `package.json` version matches new tag
- [ ] `src/index.ts` VERSION constant matches (Forge Space core only)
- [ ] CHANGELOG has entry for new version
- [ ] `[Unreleased]` section is empty (or holds only post-release additions)
- [ ] Git tag created and pushed
- [ ] GitHub Release created

## Forge Space Repo Specifics

| Repo | VERSION constant location |
|------|--------------------------|
| core | `src/index.ts` — `export const VERSION = '...'` |
| siza-gen | `package.json` only |
| ui-mcp | `package.json` only |
| mcp-gateway | `pyproject.toml` (Python) + `package.json` |
| siza | `package.json` only |

## Outputs / Evidence

Return: new version string, CHANGELOG diff summary, and confirmation that
build/tests pass after the bump.

## Failure / Stop Conditions

- Stop if `npm run build` or `npm test` fail after version bump — revert version change
- Stop if `[Unreleased]` is empty (nothing to release)
- Do not push tag until user confirms the release content

## Memory Hooks

- Read `project_overview` for current version and test counts before writing
- Write `project_overview` memory update after successful release with new version
