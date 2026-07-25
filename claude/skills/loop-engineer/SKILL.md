---
name: loop-engineer
description: "Designs and implements autonomous agent loops for any task. Trigger when the user wants to stop manually prompting agents and build a self-running feedback cycle — coding automation, research pipelines, content workflows, CI loops, or any repeating AI-driven process. Also trigger for \"design a loop\", \"build an agent loop\", \"I want this to run automatically\", or when describing a workflow currently driven manually. Output: complete loop spec plus working implementation."
triggers:
  - design loop
  - build agent loop
  - automation
  - run automatically
---

# Loop Engineer

You are not writing a prompt. You are designing a job — a feedback system that
discovers, plans, executes, verifies, and iterates until the work is done,
without a human manually driving each step.

## Preamble — RAG pre-flight

Before starting any design work, query prior loop designs for this exact task domain.
See [standards/skill-patterns.md §rag-first](../standards/skill-patterns.md) and
[§mount-guard](../standards/skill-patterns.md).

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG unreachable"; exit 1; }
python3 ~/.claude/rag-index/query.py "loop design <task-domain> precedent" --top 5
```

- If result shows a loop design for the same domain within the last 24h → surface it,
  ask user to confirm whether to reuse or start fresh.
- If no recent match → proceed directly to Phase 0.

**Done when:** RAG queried; prior loop cited or confirmed absent.

---

## Output schema

Every run of this skill produces exactly these files:

```
goal-card.md           ← Phase 0: confirmed goal + done-when criterion
architecture.md        ← Phase 1+2: architecture + mode decision with rationale
cycle.md               ← Phase 3: 5-stage cycle mapped to THIS task concretely
building-blocks.md     ← Phase 4: 6 building blocks spec table
implementation.md      ← Phase 5: the actual runnable artifact
reconciliation-template.md ← Phase 6: the loop run output template
```

Save each file as you complete the phase — do not batch them at the end.

---

## Six-phase workflow

Work through the phases below in order. Each phase produces a named output file.
Do not skip phases or merge them.

**[Phase 0 — Goal Characterization](references/phase-0-goal.md)**
Interview the user (5 questions), synthesize Goal Card, wait for user approval before Phase 1.

**[Phase 1+2 — Architecture & Mode Decision](references/phase-1-2-architecture.md)**
Decide loop size (single-agent vs. fleet) and mode (closed vs. open). Run critic gate.
Confirm decisions with user before Phase 3.

**[Phase 3 — 5-Stage Cycle Design](references/phase-3-cycle.md)**
Map Discover → Plan → Execute → Verify → Iterate stages concretely to THIS task.
Define stop condition and escape hatch. Confirm with user before Phase 4.

**[Phase 4 — 6 Building Blocks](references/phase-4-blocks.md)**
Specify: Automations, Worktrees, Skills, Connectors, Subagents, Memory.
See [building-blocks.md](references/building-blocks.md) for detailed examples.

**[Phase 5 — Implementation](references/phase-5-implementation.md)**
Generate runnable artifact (SKILL.md, Workflow script, or shell script).
See [loop-templates.md](references/loop-templates.md) for templates.
Must contain actual CLI flags/paths — no placeholders.

**[Phase 6 — Handoff & Reconciliation](references/phase-6-handoff.md)**
List all 6 output files and paths. Show exactly how to invoke the loop.
Write reconciliation template that loop outputs on every run.

---

## Recommended reading

- [cost-guide.md](references/cost-guide.md) — token cost estimates for common loop patterns
- [discipline.md](references/discipline.md) — common rationalizations refuted, hard rules
