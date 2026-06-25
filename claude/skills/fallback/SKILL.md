---
name: fallback
description: Recover cleanly when the preferred tool, skill, or execution path fails — e.g., MCP server down, CI tool unreachable, worktree conflict, or hook crash. Selects the next-best path (alternate tool, cached state, manual step) without losing accumulated context. Use proactively when a tool call errors unexpectedly, not after exhausting all retries blindly.
triggers:
  - fallback
  - plan b
  - alternate path
---

# fallback

Use when the preferred path is blocked.

## Fallback ladder

1. Capture the exact failure.
2. Keep the same intent, reduce the dependency.
3. Try the nearest lower-risk alternative.
4. If all safe paths fail, checkpoint and escalate.

## Examples

- GitHub MCP unavailable → use `gh` CLI
- Local RAG unavailable → read the smallest needed files directly
- Build too slow for broad validation → run narrow checks first
- Background watcher unavailable → poll explicitly and report the gap
