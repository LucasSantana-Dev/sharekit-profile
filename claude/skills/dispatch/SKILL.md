---
name: dispatch
description: |
  Parallelize independent evidence-gathering or audit work by splitting into ≥2 concurrent agent tracks; reconcile results into single verdict + action. Use when (1) sub-tasks are cleanly separable with no output deps, (2) each would block progress if sequential, (3) running serially wastes turns. Examples: multi-repo scans, concurrent CI/lint/test audits, N-package dependency sweeps, parallel PR review passes, docs standards comparison. Skip when tasks depend on prior output — use loop or plan instead.
triggers:
  - dispatch
  - parallelize this
  - investigate in parallel
  - run N scans in parallel
  - concurrent audits
metadata:
  owner: Lucas Santana
  tier: execution
  canonical_source: null
---

# dispatch

Split independent work into ≥2 concurrent agent tracks.

## Preamble — RAG pre-flight

Before planning dispatch, query prior dispatch runs for this task domain:

```bash
graphify query "dispatch <task-domain> agent plan" --budget 300
```

- If result shows a dispatch plan for the same task within 24h → surface it, ask user to confirm whether to reuse agent assignments or start fresh.
- If no recent match → proceed to Phase 1.

**Done when:** cached dispatch plan surfaced or no match found (proceed).

---

## When to use

- Per-repo scans (multiple repos, no cross-repo deps)
- CI/lint/test audits (independent job analysis)
- Dependency audits (N packages in one sweep)
- Multiple PR review passes (independent review lenses)
- Standards or docs comparison (independent sources)

## Workflow

### Step 1: Validate independence
Check that each track does NOT depend on output from another track. **Done when:** you can name each track's input + output without forward references.

### Step 2: Define track specs
For each track, name:
- Input (what it starts with)
- Single responsibility (what it answers)
- Output format (bullet list, counts, verdict, or artifact path)

**Done when:** each track has ≥1 sentence describing its output, printed for user review; user has not objected within 10s.

### Step 2a: Critic gate (after agent plan is drafted)

Dispatch ONE `Explore` agentType critic — read-only, never edits — with:

> "Challenge this dispatch plan: Which agent assignments are wrong for the task type? Which tasks are under-specified (agent will hit NEEDS_CONTEXT)? What dependency between tasks was missed? What should be sequential that was marked parallel?"

- If critic identifies ≥1 wrong assignment or missing dependency → revise plan before dispatch.
- Minor concerns → log in dispatch summary, proceed.

**Done when:** critic verdict returned; wrong assignments corrected or none found.

### Step 3: Launch in single message
Dispatch all tracks as parallel `Agent()` calls in ONE tool-use block. If ≥2 tracks touch the same git repo, each MUST run in its own worktree (`${DEV_ROOT}/.worktrees/<task>-<n>/`) to prevent index/lockfile collisions.

**Done when:** all agents launched concurrently (you see multiple Agent calls in a single tool-use block; each track assigned exactly one agent; worktrees configured for same-repo collisions).

### Step 4: Reconcile results
Collect all track outputs. For each disagreement, apply the resolution rule you named in Step 2.

**Done when:** you have one verdict, no open contradictions, one next action.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This task is simple enough to skip the critic check" | Simple tasks dispatched to the wrong agent type produce NEEDS_CONTEXT failures that waste an entire agent run |
| "I'll run these in parallel to save time" | Parallel dispatch of tasks with hidden dependencies produces merge conflicts and state corruption |
| "The agent can figure out the missing context" | Agents cannot figure out what they don't know they're missing. Under-specified tasks guarantee NEEDS_CONTEXT |
| "I'll skip the RAG pre-flight — this dispatch is unique" | Dispatch plans for similar tasks reuse the same agent assignments. 300 tokens can save 50,000 |

## Stop conditions

- **Dependency discovered:** if any track discovers it needs output from another track → halt, surface blocker, re-plan. Do not run tracks sequentially to "recover."
- **Sequential fallback:** running one track then the next is a dispatch violation → re-dispatch as parallel or use `loop`/`plan` instead.
- **Worktree collision:** two tracks writing the same repo without worktrees → halt, re-dispatch with worktrees.

## Cross-references

- Parallel execution mandatory: `standards/workflow.md §parallel-execution-mandatory`
- Agent routing + read-only enforcement: `standards/agent-routing.md`
- Dispatcher ≠ executor boundary: `CLAUDE.md` (hard rules, dispatcher-executor)

See also: `loop`, `plan`, `orchestrate` (for work with cross-track deps).
