---
name: debug
description: Quick root-cause debugging. Systematic trace-before-fix workflow for bugs, test failures, and unexpected behavior. When you need to investigate fast—why is this failing, root cause, debug this, ultradebug—run the 7-step frame inline or dispatch to systematic-debugging for full workflow.
metadata:
  owner: global-agents
  tier: alias
  canonical_source: ~/.claude/skills/systematic-debugging
---

# Debug

Quick 7-step debugging workflow. For full turn-efficiency budgets, architecture questioning, and subagent escalation triggers, see `systematic-debugging`.

**Core principle: Find root cause before fixing.** Symptom fixes are failure.

## Quick 7-Step Frame

1. **Reproduce** — get a minimal, reliable reproduction
2. **Locate** — find the exact file, line, and call path where it breaks
3. **Hypothesize** — list 2-3 competing explanations
4. **Evidence** — for each hypothesis: what would confirm or rule it out
5. **Test** — run the fastest confirming/ruling test first
6. **Fix** — change exactly what the evidence points to
7. **Verify** — confirm fix resolves the issue, run full test suite

## Inline Rules

- Never change code before you know the root cause
- Read the actual error message — don't skim it
- Check assumptions: is the value what you think it is? Add a log
- Distinguish "symptom" from "cause" — fix the cause
- If stuck after 3 hypotheses, add instrumentation before guessing more

## When to Escalate

For turn-efficiency budgets, architecture questioning (3+ failed fixes), subagent escalation triggers, red flags, and debugging churn prevention, invoke `/systematic-debugging` instead. Both workflows share the same non-negotiable: root cause FIRST, fixes SECOND.

## Output

```text
Root cause: <one sentence>
Location:   <file>:<line>
Fix:        <what to change and why>
```
