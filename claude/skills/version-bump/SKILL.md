---
name: version-bump
description: Automate version bumping in npm monorepos with CHANGELOG promotion and PR automation
user-invocable: true
argument-hint: <NEXT_VERSION> (e.g., 2.7.0)
metadata:
  owner: lucas-dev
  tier: production
  canonical_source: ~/.agents/skills/version-bump
invocation_type: internal
triggers:
  - version bump
  - bump version
  - release version
  - semver
---

Automate version bumping across an npm monorepo (npm workspaces), promote CHANGELOG entries, and open a PR with auto-merge enabled.

## Prerequisites

- Active git repo with root `package.json` and npm workspaces in `packages/*/package.json`
- `CHANGELOG.md` exists with `[Unreleased]` section
- Git repo is clean (no unstaged changes)
- GitHub CLI (`gh`) is installed and authenticated
- Current branch is `main` (or `master`)

## Workflow

1. **Validate version argument**: Ensure `NEXT_VERSION` matches semantic versioning (e.g., `2.7.0`)
2. **Check git state**: Fail if uncommitted changes exist or if `NEXT_VERSION` is already tagged
3. **Bump versions**: Update root `package.json` and all `packages/*/package.json` to `NEXT_VERSION`
4. **Promote CHANGELOG**: Move `[Unreleased]` section header to `[NEXT_VERSION] - YYYY-MM-DD` (today's date)
5. **Create branch**: `chore/bump-NEXT_VERSION`
6. **Commit**: Message = `chore: bump version to NEXT_VERSION`
7. **Push**: Push the branch to origin
8. **Open PR**: Use `gh pr create --auto-merge` with standard description
9. **Verify**: Confirm tag does not exist before proceeding; never force-push

## Safety rules

- **No force-push**: Uses `git push origin <branch>` only
- **Tag conflict check**: Stop if git tag `vNEXT_VERSION` (or `NEXT_VERSION`) exists
- **Clean repo only**: Fail if `git status` shows changes
- **Reversible**: If PR creation fails, user can manually delete the branch

## Usage examples

```bash
# Bump to 2.7.0
/version-bump 2.7.0

# In a monorepo
/version-bump 1.15.3
```

## Output / Evidence

- Confirm root and all package `package.json` files were updated
- Confirm CHANGELOG entry was promoted with today's date
- Link to the opened PR with auto-merge status

## Implementation hints

- Use `jq` or npm's built-in tools to update `package.json` versions
- Parse CHANGELOG.md with regex to find and replace `[Unreleased]` header
- Validate `semver` format before proceeding (e.g., `2.7.0` not `2.7`)
- Use `git tag -l NEXT_VERSION` to check for duplicate tags
- Include the new PR link in the final report
