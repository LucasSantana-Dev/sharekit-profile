---
name: session-cleanup
description: Clean up the current session state so work can transition cleanly to
  a new topic or finish without leaving loose context behind. Use when the user wants
  to reset, compact, or end a working context after a major task.
disable-model-invocation: true
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: $HOME/.agents/skills/session-cleanup
---














Clean up the current session and prepare for fresh work.

## Cleanup steps

1. **Summarize completed work** — what was accomplished this session
2. **Check for uncommitted changes**: !`git status --short 2>/dev/null || echo "Not in git repo"`
3. **Warn about unsaved progress** — if there are staged/unstaged changes, ask before clearing
4. **Suggest `/sync-memories`** if significant work was done (new patterns, gotchas, decisions)
5. **Suggest `/compact`** to compress context
6. **Report cleanup status**

## Output

```
Session Cleanup
────────────────────
Accomplished: [brief summary]
Git status:   [clean/uncommitted changes]
Memory sync:  [needed/not needed]
Action:       [compact/clear/ready]
```

## Safety

- NEVER delete files or branches without explicit confirmation
- NEVER auto-commit — only suggest commits
- NEVER clear context if there are uncommitted changes without warning
- Always ask before destructive actions

## Failure / Stop Conditions

- Stop if key prerequisites are missing or the request changes scope enough that the current workflow no longer fits.

## Memory Hooks

- Read memory when product, repo, or workflow history affects correctness.
- Write memory only if this work establishes a durable policy or convention.
