# Building Blocks Reference

Detailed examples for each of the 6 building blocks.

## 1. Automations

The trigger that starts the loop without human action.

| Trigger type | How to implement |
|---|---|
| Cron / schedule | launchd plist (macOS) or cron job — `~/.claude/skills/<name>/scripts/install-launchd.sh` |
| GitHub event | GitHub Actions workflow — `.github/workflows/<name>.yml` |
| PR opened/updated | `on: pull_request` trigger in Actions |
| File change | `fswatch` + shell script, or VS Code task |
| Test failure | CI step that calls the loop on failure |
| Manual command | Slash command — just the SKILL.md is enough |

**launchd example (daily at 03:00):**
```xml
<key>StartCalendarInterval</key>
<dict>
  <key>Hour</key><integer>3</integer>
  <key>Minute</key><integer>0</integer>
</dict>
```

**GitHub Actions example (on PR):**
```yaml
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  loop:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: claude -p "$(cat .claude/skills/my-loop/SKILL.md)" --max-turns 20
```

## 2. Worktrees

Isolation for parallel agents that write to the same repo.

```bash
# Create worktree for agent N
git worktree add \
  "${DEV_ROOT}/.worktrees/<loop-name>-<n>" \
  -b "loop/<loop-name>-<timestamp>-<n>"
```

**When to use**: Only when ≥2 agents write code in parallel. Single-agent loops
and read-only (Explore) agents do not need worktrees.

**Cleanup**: After the loop completes, remove worktrees:
```bash
git worktree remove "${DEV_ROOT}/.worktrees/<loop-name>-<n>"
git branch -d "loop/<loop-name>-<timestamp>-<n>"
```

## 3. Skills (context injection)

What the agent reads at start to avoid beginning cold.

**Typical files to inject:**
- `VISION.md` — project purpose and north star
- `ARCHITECTURE.md` — system structure
- `CLAUDE.md` — rules and conventions
- `.claude/standards/` — code standards, testing standards
- Prior run memory — what was tried last time, what passed/failed

**Pattern**: At the top of every loop, before any action:
```
1. Read VISION.md (if exists)
2. Read ARCHITECTURE.md (if exists)
3. Query memory for prior loop runs: `graphify query "<loop-name> prior run"`
4. Load accepted risks / known issues from memory
```

## 4. Connectors

External tools the loop touches beyond the local filesystem.

| Tool | How | When |
|---|---|---|
| GitHub | `gh` CLI or MCP github tools | Open PRs, post comments, watch CI |
| Linear | MCP linear tools | Create/update tickets, read backlog |
| Slack | Slack MCP or webhook | Post summaries, alert on failures |
| Gmail | Gmail MCP | Outreach loops, notification emails |
| Database | Direct connection or API | Persist structured results |
| Staging API | `curl` or SDK | Integration tests in verify phase |

**Principle**: Prefer MCP tools over raw curl when available — they handle auth
and provide structured responses. List required connectors in the skill's
`compatibility` frontmatter.

## 5. Subagents

The maker/checker split is the most important quality lever.

**Maker agents** (write-capable):
- `agentType: "general-purpose"` — general implementation
- `agentType: "test-engineer"` — writing tests
- `agentType: "debugger"` — fixing failing code
- `agentType: "writer"` — writing content/docs

**Checker agents** (read-only by construction):
- `agentType: "critic"` — adversarial review, severity calibration
- `agentType: "code-reviewer"` — code quality, correctness
- `agentType: "Explore"` — discovery/analysis only
- `agentType: "security-reviewer"` — security-specific review

**Rule**: For any quality-sensitive output, the checker must not be the same
agent that made the output. Spawn a fresh checker subagent.

**Parallel dispatch pattern** (for fleet loops):
```javascript
// Workflow script
const results = await parallel(SPECIALISTS.map(s => () =>
  agent(s.prompt, { label: s.name, agentType: "Explore", phase: "Discover" })
))
```

## 6. Memory

How the loop persists state so the next run is not starting from zero.

**Memory locations (in priority order):**

1. **`~/.claude/memory/`** — project-level memory files (auto-loaded next session)
2. **`.claude/loop-state/<loop-name>/`** — loop-specific state in the repo
3. **GitHub Issues** — open issues as persistent task lists
4. **Linear tickets** — structured work items
5. **Markdown files in repo** — `docs/loop-runs/YYYY-MM-DD.md`

**What to save after every run:**
- Outcome (PASSED / FAILED / ESCALATED)
- What was discovered this run
- What was tried and whether it worked
- What failed and why
- Accepted risks / known issues to skip next time
- Next trigger timestamp

**Memory write pattern:**
```bash
# Append-only log (safe for concurrent writes)
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | PASSED | 3 cycles | fixed: auth/jwt.ts" \
  >> .claude/loop-state/coding-loop/run-log.md
```
