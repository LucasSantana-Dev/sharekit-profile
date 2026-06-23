---
name: smart-model-select
description: Pick the lightest model or reasoning tier that can do the task well. Auto-triggered via complexity-classifier.sh hook on every prompt. Use this skill explicitly when you want to override or review the classification.
triggers:
  - model select
  - choose model
  - route by complexity
  - what model should I use
---

# smart-model-select

## How it works

The `complexity-classifier.sh` hook fires on every `UserPromptSubmit` and injects an `[AUTO]` system message with:
- **COMPLEXITY level**: low / medium / high / critical
- **Recommended model** for subagent Agent tool calls
- **Effort guidance**

Claude reads this and calibrates response depth + subagent model selection automatically.

## Classification rules

| Level | Signals | Reasoning | Agent tool model |
|-------|---------|-----------|-----------------|
| **low** | Short (<20 words) + search/find/list/lookup keywords | Light | `haiku` |
| **medium** | General coding (default) | Normal | `haiku` (lookup) or `sonnet` (multi-file) |
| **high** | implement/build/debug/refactor/PR work/skill invocations | Thorough | `sonnet` |
| **critical** | arch/security/migrate/audit/CVE/production/rollback/hotfix | Extended | `opus` |

The main session model stays Sonnet unless you explicitly use `/model`.

## Bloom's taxonomy — override mental model

When the AUTO hint feels wrong, classify by cognitive level instead:

| Bloom Level | Task type | Recommended model |
|------------|-----------|-------------------|
| L1 Remember | recall, lookup, list, find | haiku |
| L2 Understand | explain, summarize, describe | haiku |
| L3 Apply | run, execute, format, transform | haiku |
| L4 Analyze | debug, trace, compare, find root cause | sonnet |
| L5 Evaluate | code review, assess risk, PR review | sonnet |
| L6 Create | design, architect, build new system | opus |

## For Agent tool calls — always pass model explicitly

```python
# Simple subagent (search, triage, format) — Bloom L1–L3
Agent(model="haiku", prompt="...")

# Complex subagent (multi-file analysis, code review) — Bloom L4–L5
Agent(model="sonnet", prompt="...")

# Critical subagent (security audit, architecture) — Bloom L6
Agent(model="opus", prompt="...")
```

`CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001` is the session default.
Override with `model:` when the task is clearly high/critical complexity.

## Cascading pattern (manual override)

For borderline tasks, start cheap and escalate only if the result is insufficient:

```python
# Phase 1: try cheap model
result = Agent(model="haiku", prompt="explain the auth refresh flow")

# Phase 2: escalate only if result is incomplete or unclear
result = Agent(model="sonnet", prompt="explain the auth refresh flow — include edge cases and failure modes")
```

This reduces cost ~60% on queries that don't actually need a flagship model.

## Switching main model mid-session

```
/model claude-opus-4-7    # for architecture/security work
/model claude-sonnet-4-6  # switch back after
```

## Effort control

`effortLevel: "medium"` is the session default (set in settings.json).
Use `/think` to trigger extended reasoning for critical individual tasks.

## Heuristics (reference)

**Use lighter reasoning for (Bloom L1–L3):**
- search, grep, listing, formatting
- routing decisions
- simple single-file edits
- mechanical triage
- recall/explain/translate

**Use deeper reasoning for (Bloom L4–L6):**
- architecture design
- security-sensitive changes
- complex debugging
- migrations
- consequential PR review
- multi-repo orchestration

Checkpoint before switching models or moving to an unrelated task.
