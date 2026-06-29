---
name: optimize-context
description: Reduce token consumption and improve context efficiency. Use when context
  is bloated, responses are slow, or approaching context limits.
argument-hint: '[analyze|compact|targeted|mcp-first]'
metadata:
  owner: global-agents
  tier: contextual
---














Optimize context for the current session. Mode: `$ARGUMENTS` (default: full optimization).

## Strategy priority

1. **Remove irrelevant context**: Files and conversation turns not related to current task
2. **Use @file references**: Instead of reading full file contents into context
3. **Delegate to subagents**: Move independent research out of main context
4. **MCP-first**: Use MCP tools (Context7, Serena) instead of reading raw files
5. **Compress**: Use `/compact` when context exceeds ~70% window

## Analysis steps

1. Estimate current context usage level (low/medium/high/critical)
2. Identify the 3 largest context contributors
3. Determine which are still relevant to the active task
4. Suggest specific removals or compressions

## Quick actions

| Mode | Action |
|------|--------|
| `analyze` | Report context state without changes |
| `compact` | Run `/compact` immediately |
| `targeted` | Ask what the current task is, then prune everything else |
| `mcp-first` | Suggest MCP alternatives for any raw file reads |

## Output

```
Context Optimization
────────────────────
Usage:     [low/medium/high/critical]
Top 3:     [largest context items]
Relevant:  [yes/no for each]
Action:    [recommended next step]
Savings:   [estimated reduction]
```

## Failure / Stop Conditions

- Stop if required credentials, environment access, or prerequisite context are missing.
- Stop if the workflow would report unverified work as complete.
- Do not bypass required gates or safeguards unless the user explicitly asks for it.

## Memory Hooks

- Read memory when product, repo, or workflow history affects correctness.
- Write memory only if this work establishes a durable policy or convention.
