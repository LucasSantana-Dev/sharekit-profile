---
name: parallel-work-coordinator
description: >
  Orchestrate 3–5 independent tasks in parallel with auto-dispatch and reconciliation.
  Use when you have multiple independent work items (multi-repo audits, multi-file translations,
  parallel investigations, fan-out sweeps). Invoke when the user says "do all of these",
  "check all repos", "audit these in parallel", or "handle these independently".
  Also auto-trigger when you detect sequential work that could safely parallelize.
  This skill wraps multi-agent dispatch for lightweight jobs; use Workflow for heavy
  orchestration with loops, conditionals, or large fleets (>5 units).
triggers:
  - parallel work
  - do all these
  - audit in parallel
  - independent tasks
---

# Parallel Work Coordinator

Dispatch independent work units in parallel with sensible defaults, collect results, and reconcile findings without Workflow overhead.

## When to use

- **Multi-repo sweeps:** "Audit these 4 repos for security issues"
- **Multi-file operations:** "Translate these 3 document groups to PT-BR"
- **Parallel investigations:** "Check these 5 error logs for the same root cause"
- **Fan-out analysis:** "Review each of these 4 approach proposals for feasibility"
- **When you detect sequential-by-default:** User is about to run N independent tasks one-by-one; suggest parallelism

**Boundary:** If work has cross-unit dependencies (task B needs output from task A) or requires loops/conditionals, use `/loop` or the Workflow tool instead. This skill is for the happy path — fully independent units.

## Why this matters

CLAUDE.md hard rule #2: "Parallel execution is mandatory for ≥2 independent tasks." But setting up Workflow requires a YAML script and cloud billing. For 3–5 independent tasks with no interdependencies, this skill provides the structure without the overhead — and enforces the mandatory parallelism.

## Workflow

### Phase 1 — Scan & Decompose

Read the user's request or the active plan. Extract independent work units:
- **Example 1:** "Audit repos A, B, C for security" → 3 units (one per repo, independent)
- **Example 2:** "Translate files X, Y, Z to PT-BR" → 3 units (one per file group, independent)
- **Example 3:** "Check logs 1–5 for root cause" → 1 unit (they share context; run as one sweep, not 5 independent sweeps)

**Key question:** Does unit B need the output of unit A? If yes → not independent. Flag it, note the dependency, and suggest sequential execution instead.

Output: `N independent units identified` (or "these are not truly independent — recommend sequential execution instead").

Done when: all N units decomposed and dependencies mapped.

### Phase 2 — Plan Dispatch

For each unit:
1. Assign a **label** (short, descriptive: `repo-a-security`, `pt-br-files-1-50`, etc.)
2. Assign a **worktree path** (if the unit touches a git repo):
   - If 2+ units touch the same repo → each unit gets its own worktree: `${DEV_ROOT}/.worktrees/<label>-<n>/`
   - If each unit touches a different repo → no worktree needed (work in place)
3. Draft an **agent prompt** (what the agent should do for this unit; include the scope and success criteria)

Output: Dispatch plan with unit labels, worktree assignments, and prompts.

Done when: dispatch plan includes labels, worktree assignments, and prompts for all units.

### Phase 3 — Dispatch (Mandatory Single Turn)

Emit all Agent() calls in ONE message using the Bash tool to spawn parallel agents.

**CRITICAL:** This must be one message, not N sequential turns. The entire point is to start all agents at the same time.

Example structure:
```
Agent 1 prompt: <unit-1-work>
Agent 2 prompt: <unit-2-work>
Agent 3 prompt: <unit-3-work>
[all three run in parallel]
```

### Phase 4 — Collect

As agents complete, collect their outputs. Do NOT wait for all to finish before moving to Phase 5 — collect progressively.

Done when: first agent output received and queued for reconciliation.

### Phase 5 — Reconcile

For each unit's output:
1. **Surface the unit's result:** Did it succeed, hit a blocker, or need human input?
2. **Cross-check for contradictions:** If units 1 and 2 both audited repo X and found different things, note it
3. **Gate:** If ANY unit is blocked, surface the blocker first. Do NOT silently continue to the next phase
4. **Consolidate findings:** Merge non-contradictory results; flag contradictions for human review

Output format:
```
PARALLEL WORK COORDINATOR

Units dispatched: 3
Units completed: 3
Blockers: 0

Per-unit status:
  1. <label>: ✓ DONE — <one-line finding>
  2. <label>: ✓ DONE — <one-line finding>
  3. <label>: ✓ DONE — <one-line finding>

Consolidated findings:
  <merged high-level insights>

Contradictions:
  (none)

Next phase: <recommendation — "ready to merge", "needs review", "blocked on X", etc.>
```

## Stop conditions

- **Work is not independent:** If any unit depends on another's output → surface this immediately. Recommend sequential execution. Do NOT force parallelism on dependent work.
- **Worktree collision detected:** If 2+ units touch the same repo but weren't assigned separate worktrees → halt and alert the user; apply the worktree rule before dispatching
- **Blocker found:** If a unit hits an error, permission issue, or missing resource → surface it as a gate blocker; do not automatically retry or skip
- **More than 5 units:** This skill caps at 5 independent units. If the user has 6+, suggest Workflow instead (which handles arbitrary fleet sizes)

## Examples

See `references/examples.md` for detailed walkthrough of multi-repo security audit and batch file translation scenarios.

## Key behaviors

- **Independence detector:** If the user's request implies dependencies, call it out and refuse to parallelize. Better to be conservative than to create race conditions.
- **Worktree discipline:** Always apply the rule: "When 2+ parallel agents touch the same repo, each one MUST run in its own git worktree." Never skip this.
- **Mandatory single-turn dispatch:** All Agent() calls in one message. This enforces true parallelism.
- **Gate blocker:** Do NOT continue to the next phase if any unit is blocked. Surface the blocker and wait for human decision.
- **Short output:** Reconciliation report is concise (3–4 lines per unit). Reference full logs if the user wants details.

## Hardening (lessons from shorts-edit-cli Rust rewrite, 2026-07-04)

- **Exit-gate contract (mandatory for write units):** every agent prompt must require the agent to PASTE the raw last-line output of each verification command (build/test/lint/parity) — a pass claim without pasted output = unit failure. Orchestrator still re-runs at least the cheapest gate per unit before merging. Rationale: 4 consecutive waves shipped false clippy-clean claims; 3 fake parity harnesses on one unit; one fabricated "deltas=0.0".
- **Build before parity in fresh worktrees:** parity/integration scripts that invoke a compiled binary MUST be preceded by the build command in the same verification run. A fresh worktree with an unbuilt binary produced a false "2/23 parity" alarm.
- **Wave sizing:** cap write agents at 2–3 per wave; merge fully between waves. Defect rate and registration-file merge conflicts scale with concurrent writers.
- **Registration hotspots:** when parallel units all register into shared files (main dispatch, mod.rs, Cargo.toml), either serialize those edits into a scaffold/integration unit first, or use codegen/per-domain registration files. Never resolve conflicting bash heredocs with `git merge-file --union` — it corrupts heredoc terminators; resolve by hand.
- **Fix-loop resumes:** prefer a fresh agent with a compact state packet (git diff + failing output + file slice, ~5–10k tokens) over resuming a completed agent (re-reads its full transcript, 44–171k tokens observed). Resume only when the agent's context is genuinely load-bearing.
- **Model tiering:** write/port units → `model: sonnet`; mechanical doc/config units → `model: haiku`; critics/judges keep their agent-type default. Apex tier is for the orchestrator's own reasoning, not routine execution.
- **Analysis-blocker refutation:** when an agent claims a library/API blocker ("crate doesn't export X"), scratch-compile a minimal probe BEFORE accepting — one refuted false blocker saved a whole unit from being stubbed.
