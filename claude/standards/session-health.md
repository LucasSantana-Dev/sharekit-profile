# Session Health & Token Budget Monitoring

## Budget thresholds

| Level | Context used | Action |
|-------|-------------|--------|
| Green | <60% | Normal work |
| Yellow | 60–80% | Prefer narrow reads; avoid broad file dumps |
| Orange | 80–90% | Compact at next task boundary; no new broad explorations |
| Red | >90% | Write handoff immediately, compact or end session |

The `complexity-classifier.sh` hook injects budget signals at session start. The `session-budget` standard governs the same thresholds — this doc adds monitoring mechanics.

## Signals that budget is degrading

- Responses getting slower or truncated
- Claude re-reading files it already has in context
- Same tool called multiple times with identical args
- Responses drifting — forgetting earlier decisions

## Monitoring during work

Track cost with `/cost` at task boundaries. A healthy session for a medium feature:
- Simple bug fix: <20k tokens
- Multi-file feature: 40–80k tokens
- Full backlog session: 100–200k tokens

Anything pushing 300k+ on a single task is a signal to compact or split.

## When to compact

- After merging a PR (clean boundary)
- Before switching to an unrelated task
- When the working tree is clean and CI is green
- When context is >80% and the next step is a fresh sub-task

Run `/compact` — it summarizes the session into a dense block and drops raw tool outputs. Follow with `/resume` in the new session to rehydrate from handoffs and plans.

## Handoff before cutoff

At 90%+ budget, write a handoff before compacting:

```bash
# The `handoff` skill handles this:
# - current branch, PR, CI state
# - decisions made this session
# - immediate next step with file paths
# - open questions
```

A handoff written at 85% is useful; one written at 99% after truncation is not.

## Token-expensive operations to avoid near budget limit

- Reading entire large files (use offset/limit)
- Running broad `find` or `grep` without scoping
- Re-reading files already in context
- Spawning subagents inline instead of backgrounded
