---
name: context-pack
description: >-
  Build a task-aware context bundle before large changes, reviews, or unfamiliar work. Pul
  l only the code, standards, plans, RAG hits, and notes that matter instead of reading wi
  de. Use before refactors, cross-file fixes, unfamiliar repos, or when starting a session
   where you will spend more than five reads exploring. Backed by the local RAG index via 
  the rag_query MCP tool. Skip when the task touches one known file or the answer fits in 
  a single grep.
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
See also [standards/user-context.md](standards/user-context.md) — context load order (repo state → handoff → plan → memory → standards).

## Rules

See [references/discovery-strategy.md](references/discovery-strategy.md) §Symbol lookup strategy, §Chunking discipline, and §Anti-patterns for task-scoped retrieval rules.

## Failure / Stop Conditions

- **Mount guard:** If External HD unmounted → `rag_query` degrades; fall back to grep + claude-mem. Check before starting: `mount | grep -q "${DEV_ROOT}" || echo "BLOCKED: External HD unmounted — RAG/vault unreachable"`.
- If RAG retrieval returns nothing and no plans/handoffs exist for the topic → read the 2-3 most relevant files directly; do not expand the read set speculatively.
- Stop accumulating context when the next read would not change the action — marginal reads waste budget and dilute signal.
- Do not invoke context-pack for tasks touching one known file; direct read is faster.