# Phase 4 — 6 Building Blocks

Specify each building block for THIS loop. Use the table format below. For blocks that don't apply, state why (e.g., "Worktrees: N/A — single-agent, no parallel file writes").

See [building-blocks.md](building-blocks.md) for detailed examples of each block.

## Building blocks table

| Block | Used? | Implementation detail |
|-------|-------|-----------------------|
| Automations | Yes/No | ___ |
| Worktrees | Yes/No | ___ |
| Skills | Yes/No | ___ |
| Connectors | Yes/No | ___ |
| Subagents | Yes/No | ___ |
| Memory | Yes/No | ___ |

## Block definitions

**Automations**: what starts the loop without manual action? (cron, GitHub webhook, launchd, CI hook — include the specific event, not just the tool)

**Worktrees**: only when ≥2 agents write code in parallel. Path: `${DEV_ROOT}/.worktrees/<loop-name>-<n>/`

**Skills**: which SKILL.md files or context files (VISION.md, ARCHITECTURE.md) does the agent read at start?

**Connectors**: which external tools does the loop call? List specific CLI commands or MCP tools, not just names.

**Subagents**: who makes, who checks? If quality-sensitive: maker and checker MUST be different agents. State `agentType` for each.

**Memory**: where does the loop persist state? Exact file paths and format. What does it read at start? What does it append after each run?

Save as `building-blocks.md`.
