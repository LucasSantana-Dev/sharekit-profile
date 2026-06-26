---
name: fallback
description: Recover cleanly when the preferred tool, skill, or path fails.
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

## Failure / Stop Conditions

- One attempt per fallback level — do not retry a fallback that already failed.
- If all safe paths are exhausted, checkpoint current state and escalate: "All paths blocked: [last failure]. Next option requires user decision."
- Do not invent a workaround that changes the security posture (e.g., disabling a check, widening permissions) as a fallback — surface it instead.

## Memory Hooks

- Read memory if the blocking tool or path has a known reliable workaround from a prior session.
- Write memory only if a new durable fallback path is confirmed working, so future sessions can skip rungs.
