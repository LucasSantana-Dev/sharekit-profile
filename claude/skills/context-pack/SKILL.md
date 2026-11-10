---
name: context-pack
description: "Build a compact, task-aware context bundle (code, standards, plans, RAG hits) before large changes, reviews or unfamiliar repos. Skip when the task touches one known file or fits one grep."
triggers:
  - context pack
  - gather relevant context
  - retrieve what matters
  - bootstrap me on this
  - load context for
---

# context-pack

Use before reading broadly.

## Goal

Pull only the code, standards, plans, and notes that matter for the task.

**Done when:** context bundle complete and next read would not change action.

## Preferred sources (in order)

See [references/discovery-strategy.md](references/discovery-strategy.md) §Preferred sources.  

## Rules

See [references/discovery-strategy.md](references/discovery-strategy.md) §Symbol lookup strategy, §Chunking discipline, and §Anti-patterns for task-scoped retrieval rules.

## Failure / Stop Conditions

- **Mount guard:** If External HD unmounted → `rag_query` degrades; fall back to grep. Check before starting: `mount | grep -q "${DEV_ROOT}" || echo "BLOCKED: External HD unmounted — RAG/vault unreachable"`.
- If RAG retrieval returns nothing and no plans/handoffs exist for the topic → read the 2-3 most relevant files directly; do not expand the read set speculatively.
- Stop accumulating context when the next read would not change the action — marginal reads waste budget and dilute signal.
- Do not invoke context-pack for tasks touching one known file; direct read is faster.
