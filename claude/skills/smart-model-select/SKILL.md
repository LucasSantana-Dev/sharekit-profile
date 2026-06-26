---
name: smart-model-select
description: Pick the lightest model or reasoning tier that can do the task well.
triggers:
  - model select
  - choose model
  - route by complexity
---

# smart-model-select

## Heuristics

Use lighter reasoning for:
- search
- routing
- formatting
- simple edits
- mechanical triage

Use deeper reasoning for:
- architecture
- security-sensitive work
- complex debugging
- migrations
- consequential PR review
- multi-repo orchestration

Checkpoint before switching models or moving to an unrelated task.
