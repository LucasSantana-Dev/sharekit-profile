---
name: loop-engineer
description: "Redesigns agent loops to reduce turns, token waste, and blind retries while preserving output quality. Designs AND implements autonomous agent loops for any task. Trigger this skill whenever the user wants to stop manually prompting agents and instead build a self-running feedback cycle — coding automation, research pipelines, content workflows, outreach systems, CI loops, or any repeating AI-driven process. Also trigger when the user says \"design a loop\", \"build an agent loop\", \"I want this to run automatically\", \"loop engineering\", or describes a workflow they currently drive manually step-by-step. Output: complete loop spec + working implementation (SKILL.md or Workflow script) ready to run."
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

Work through the six phases below in order. Each phase produces a named output
file. Do not skip phases or merge them. Do not produce a single monolithic
document — each phase is a separate file.

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

## Phase 0 — Goal characterization

Before designing anything, nail down what the loop is actually trying to do.
Interview the user with these questions (ask them all at once, not one at a time):

1. **What is the goal?** One sentence — what should the loop accomplish when it
   runs successfully?
2. **What does "done" look like?** What is the concrete pass/fail criterion that
   tells the loop to stop?
3. **What triggers the loop?** Manually, on a schedule, on an event (PR opened,
   file changed, ticket created)?
4. **How often / how long?** Daily? Per-commit? Until all tests pass?
5. **What is the cost tolerance?** Rough expectation — quick (< 50K tokens),
   medium (50K–500K), or heavy (500K+)?

Synthesize answers into a Goal Card using this exact format:

```
GOAL: <one-sentence goal>
DONE WHEN: <concrete pass/fail criterion>
TRIGGER: <what starts the loop>
CADENCE: <how often / duration>
COST TIER: quick | medium | heavy
```

**Save as `goal-card.md`.**

**Stop if:** Goal Card is vague, empty, or missing any of the 5 fields → surface
`BLOCKED: Goal Card incomplete. Missing: [field]. Next: fill in and resubmit.` Halt.

**STOP — present the Goal Card to the user and wait for confirmation before
proceeding to Phase 1.** A vague or wrong goal produces a useless loop. If the
user says "looks good" or similar, continue. If they correct it, update the
Goal Card and present again.

**Done when:** Goal Card confirmed by user (all 5 fields present, user approved).

---

## Phase 1+2 — Architecture and mode decision

See [references/cost-guide.md](references/cost-guide.md) for token cost estimates before deciding.

This phase makes two explicit decisions. Both must appear in `architecture.md`.

### Decision A: Loop size

**Single-agent loop** — one agent runs the full cycle. Best when:
- Focused, bounded task (one file, one PR, one article)
- No parallel workstreams
- Cost tier is quick or medium

**Fleet loop** — orchestrator + specialist agents. Best when:
- Multiple parallel workstreams with different skill needs
- Cost tier is medium or heavy

State which you chose and why you rejected the other.

### Decision B: Loop mode

**Closed loop** (default) — bounded path designed by the human; agent runs
inside defined steps with explicit stop conditions. 30–50% cheaper than open.

**Open loop** — agent explores its own path. Use only when the search space is
genuinely unknown and the user accepts higher cost and less predictability.

State which you chose and why. Recommend closed unless the user's goal is
explicitly exploratory.

If fleet: sketch the orchestrator + specialist breakdown in a diagram.

**Save as `architecture.md`.**

Present the decisions to the user. Confirm before Phase 3.

### Critic gate (after architecture is confirmed)

Dispatch ONE `Explore` agentType critic — read-only, never edits — with this prompt:

> "Challenge this loop architecture: What could make the loop spin forever? What
> stop condition is missing or too weak? What failure mode does the escape hatch
> not cover? What would cause the Verify stage to always pass even when it should fail?"

- If critic finds ≥1 critical issue → revise `architecture.md` before Phase 3.
- If critic finds only minor concerns → log them in `architecture.md` under a
  "Critic notes" section and proceed.

Done when: critic verdict returned; critical issues resolved or none found.

---

## Phase 3 — 5-stage cycle design

Map the five stages to THIS task. Each entry must be concrete — not "Execute =
do the task" but "Execute = run `npm test` and capture stdout/stderr". Generic
descriptions are not acceptable.

| Stage | This loop — concrete action |
|-------|-----------------------------|
| Discover | ___ |
| Plan | ___ |
| Execute | ___ |
| Verify | ___ |
| Iterate | ___ |

Also define:
- **Stop condition**: exact criterion to exit the loop successfully
- **Escape hatch**: after how many failed iterations does it escalate to human?

Write the cycle as a flow diagram:

```
[TRIGGER]
  ↓
Discover: <concrete action>
  ↓
Plan: <concrete action>
  ↓
Execute: <concrete action>
  ↓
Verify: <pass/fail check — be specific>
  ↓ fail
Iterate: <how it fixes and loops back>
  ↓ pass (or escalate after N failures)
[DONE / HANDOFF]
```

**Save as `cycle.md`.**

Present to user and confirm before Phase 4.

---

## Phase 4 — 6 building blocks

See [references/building-blocks.md](references/building-blocks.md) for detailed examples of each block.

Specify each building block for THIS loop. Use the table format below. For
blocks that don't apply, state why (e.g., "Worktrees: N/A — single-agent,
no parallel file writes").

| Block | Used? | Implementation detail |
|-------|-------|-----------------------|
| Automations | Yes/No | ___ |
| Worktrees | Yes/No | ___ |
| Skills | Yes/No | ___ |
| Connectors | Yes/No | ___ |
| Subagents | Yes/No | ___ |
| Memory | Yes/No | ___ |

**Automations**: what starts the loop without manual action? (cron, GitHub
webhook, launchd, CI hook — include the specific event, not just the tool)

**Worktrees**: only when ≥2 agents write code in parallel. Path:
`${DEV_ROOT}/.worktrees/<loop-name>-<n>/`

**Skills**: which SKILL.md files or context files (VISION.md, ARCHITECTURE.md)
does the agent read at start?

**Connectors**: which external tools does the loop call? List specific CLI
commands or MCP tools, not just names.

**Subagents**: who makes, who checks? If quality-sensitive: maker and checker
MUST be different agents. State `agentType` for each.

**Memory**: where does the loop persist state? Exact file paths and format.
What does it read at start? What does it append after each run?

**Save as `building-blocks.md`.**

---

## Phase 5 — Implementation

See [references/loop-templates.md](references/loop-templates.md) for starter templates.

Generate the actual runnable artifact. Choose one:

- **SKILL.md** — when invoked by human on demand
- **Workflow script** — when fully autonomous with parallel agents
- **Shell script** — when a simple linear CLI chain

For most loops: a SKILL.md (primary) + shell script (automation trigger).

The artifact must contain **actual runnable content** — real CLI flags, real
file paths, real API commands. No placeholders like `<your-repo-here>` unless
the value is genuinely unknown.

Implementation constraints:
- Discovery agents: `agentType: "Explore"` (read-only)
- Checker/critic agents: `agentType: "critic"` or `"code-reviewer"`
- Memory writes: append-only — no silent overwrites
- Stop condition and escape hatch must appear explicitly in the artifact

**Save as `implementation.md`.**

**Done when:** implementation artifact created AND runnable (no placeholder tokens, actual CLI flags and paths).

---

## Phase 6 — Handoff and reconciliation template

1. List all 6 output files with their paths
2. Show the user exactly how to invoke the loop
3. If an automation trigger was designed, include the exact config to install
   (launchd plist XML, cron entry, GitHub Actions YAML, etc.)

Write a reconciliation block template that the loop outputs on every run:

```
LOOP RUN — <loop-name> @ <timestamp>
  Trigger:      <what started this run>
  Goal:         <one-line goal>
  Cycle:        <N iterations run>
  Discover:     <what was found> [OK] | [WARN] | [FAIL]
  Plan:         <what was planned> [OK] | [WARN] | [FAIL]
  Execute:      <what was done> [OK] | [WARN] | [FAIL]
  Verify:       <pass/fail + criterion> [OK] | [FAIL]
  Iterate:      <N retries, last error if any> [OK] | [WARN] | (skipped)
  Outcome:      PASSED | FAILED | ESCALATED TO HUMAN
  Memory:       <what was saved for next run>
  Next trigger: <when this loop will run again>
```

**Save as `reconciliation-template.md`.**

**Done when:** reconciliation template created AND all 6 output files listed with paths.

---

See [references/discipline.md](references/discipline.md) — common rationalizations refuted and hard rules.

## Reference files

- `references/building-blocks.md` — detailed examples for each of the 6 blocks
- `references/loop-templates.md` — starter templates for coding, research,
  content, and outreach loops
- `references/cost-guide.md` — token cost estimates for common loop patterns
- `references/discipline.md` — common rationalizations refuted, hard rules
