# sync-memories: forgekit workflow

After shipping a PR in the forgekit monorepo, run `/sync-memories` to persist session state.

## What to update

1. **claude-mem observations** — call `mcp__plugin_claude-mem_mcp-search__save_memory` with:
   - `project: "forgekit"`
   - One observation per milestone: PR merged, version bumped, bug confirmed

2. **Local `.agents/memory/in-progress.md`** — rewrite with current session state:
   - What completed (PR numbers, commit hashes)
   - What's open (outstanding issues, version discrepancies)
   - Current branch and clean working tree status

3. **`project_web_ui_state.md`** in `~/.claude/projects/.../memory/` — update when web UI changes shipped

## Forgekit-specific triggers

- After `gh pr merge` completes
- After a version bump (`package.json` + `CHANGELOG.md` + git tag)
- After catalog index rebuild (`pnpm catalog:index`)
- When a version/tag discrepancy is discovered and fixed

## Files to update

| File | When |
|------|------|
| `.agents/memory/in-progress.md` | Every session that changes repo state |
| `~/.claude/projects/.../memory/project_web_ui_state.md` | After web UI PRs |
| claude-mem #NNNN | Milestones, gotchas, version state |

## Common gotchas in forgekit

- `v0.18.0` tag pattern: tag gets cut before `package.json` bump — check both match
- Local `main` diverges after squash-merge PRs — use `git reset --hard origin/main`
- No Serena in this project — skip Serena memory steps entirely
