# Session Budget

## Thresholds (absolute tokens, source of truth: `session-budget-guard.sh`)

Measured against tokens still free in the window, not percent used. `session-budget-guard.sh` encodes the formula but is currently unwired, so apply the lines yourself from the statusline `ctx:N%` (percent used):

| Level | 200k window, ~45k baseline | 1M window, ~45k baseline | Action |
|---|---|---|---|
| Normal | above ~48k left (under ~76% used) | above ~220k left (under ~78%) | Work as usual |
| Soft | below ~48k (~76% used) | below ~220k (~78%) | Finish the task, `/compact` at the next clean breakpoint |
| Hard | below ~33k (~84% used) | below ~125k (~88%) | Write the handoff now, then compact or end the session. No new broad explorations; run subagents backgrounded |

The hook computes hard as 13% of usable context (window minus fixed baseline), plus half of any baseline above 10% of the window, plus 5% of usable when 20+ subagent runs happened. Soft is hard plus 10% of usable. A heavier baseline or 20+ subagent runs raises both lines. The numbers above are the typical cases, not a second source: if they disagree with the hook formula, the formula wins.

## Rules

- Prefer narrow reads over broad context dumps; use offset/limit on large files, scope every `find` and `grep`.
- Compact when the task changes substantially or the context turns noisy. Good boundaries: after a PR merges, before an unrelated task, clean tree with green CI.
- Checkpoint (handoff) before switching tasks. Model changes follow `model-tiering.md`: only at a task boundary in a fresh session.
- Rehydrate with retrieval, plans and handoffs instead of carrying everything inline. `/compact`, then `/resume` in the new session.
- A handoff written before the hard line is useful; one written after truncation is not. The `handoff` skill writes it (branch, PR and CI state, decisions, next step with file paths, open questions).
- Compaction paraphrases. Anything that must survive verbatim (task, repo and branch, PR and issue numbers, IDs, decisions, operator constraints) goes in `~/.claude/.harness/runtime/facts-<session_id>.md` as you learn it; `reinject-compact.sh` re-injects it after a compact. Long exploration (30+ reads) keeps findings in `<scratchpad>/findings.md` and re-reads it at phase boundaries.

## Signals the budget is degrading

- Slower or truncated responses; re-reading files already in context; the same tool called repeatedly with identical args; forgetting earlier decisions.

## Sizing

Check `/cost` at task boundaries. Typical: simple bug fix under 20k tokens, multi-file feature 40-80k, full backlog session 100-200k. A single task past 300k means compact or split.
