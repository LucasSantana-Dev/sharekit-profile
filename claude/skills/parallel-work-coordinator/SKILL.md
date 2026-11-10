---
name: parallel-work-coordinator
description: >
  Governance layer for small (≤5-unit) parallel batches that MIX read-only and write-capable
  agents — autonomy-tier gating (T0-T3) and worktree/merge discipline for the writes. Thin
  wrapper over dispatch; use parallel-investigate instead when every unit is read-only.
  Invoke on "do all these", "audit and fix in parallel", "handle independently".
triggers:
  - parallel work
  - do all these
  - audit in parallel
  - independent tasks
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/parallel-work-coordinator
  overlay_of: dispatch
disable-model-invocation: true
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
   - If 2+ units touch the same repo → each unit gets its own worktree: `${DEV_ROOT:-$HOME/dev}/.worktrees/<label>-<n>/`
   - If each unit touches a different repo → no worktree needed (work in place)
3. Draft an **agent prompt** (what the agent should do for this unit; include the scope and success criteria)

Output: Dispatch plan with unit labels, worktree assignments, and prompts.

Done when: dispatch plan includes labels, worktree assignments, and prompts for all units.

### Phase 3 — Dispatch (Mandatory Single Turn)

Emit all `Agent()` calls in ONE message, one call per unit, so they run concurrently. Not the Bash tool, not N sequential turns: the entire point is to start every agent at the same time.

**Read-only enforcement (`standards/agent-routing.md`).** Any unit that returns findings rather than code changes — audit, review, investigation, triage, research — gets a **write-incapable `agentType`** (`Explore`, `explore`, `Plan`, `critic`, `code-reviewer`, `security-reviewer`, `document-specialist`), so editing is structurally impossible. Only write units get `general-purpose`, `debugger`, `test-engineer`. A prompt saying "read-only" is NOT the mechanism: agents have written to disk anyway despite it. Mixed batches are normal (3 audit units read-only, 1 fixer write-capable); the read-only ones can share a checkout, the write ones cannot (worktree rule, Phase 2).

**Brief budget, per unit** (`standards/agent-routing.md` § Subagent token economics):

- Hard output cap in every prompt: "report ≤200 lines, findings with `file:line` refs, no essays". ≤400 only for a genuine deep dissection.
- Grep-first: locate the load-bearing files yourself, name the ≤5 worth a full read, say "skim everything else". Never "read every file fully" on a repo with god-files.
- `thoroughness: medium` default. One agent per question-class or per repo, never per file-group.
- Self-contained prompts: no dumping the parent conversation into the child. When the unit genuinely needs session state, fork instead.
- Recall first (`recall` / `search_knowledge` / `ctx_search`). If memory or a prior indexed report already answers a unit, that unit is not dispatched at all.

Example structure:
```
Agent 1 prompt: <unit-1-work>
Agent 2 prompt: <unit-2-work>
Agent 3 prompt: <unit-3-work>
[all three run in parallel]
```

### Phase 4 — Collect

As agents complete, collect their outputs. Do NOT wait for all to finish before moving to Phase 5 — collect progressively.

Any single output >50KB gets `ctx_index` immediately, then `ctx_search` for the answers. Never Read-page a >50KB result into the main context just to summarize it. Counts, filters and aggregations over the returned files run in `ctx_execute`; only the printed answer enters context. A failed or timed-out unit is **resumed**, never respawned; a provider quota 403 means stop dispatching, not retry the batch.

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

## Autonomy tiers (ADR-0051)

Parallelism does not lower the gate on what the units DO. Tier each unit by its action, per `standards/autonomy-tiers.md`, before dispatching:

- **T0** — read-only units (audits, sweeps, investigations, searches): dispatch silently, no gate. This is the shape most batches take.
- **T1** — branch commits, narrow edits (<5 files each), memory notes: dispatch, then report what each unit changed.
- **T2** — a unit whose scope is ≥5 files or ≥2 modules, or that touches architecture, public API, schema, dependencies, or global hook/standard behavior: it needs ONE adversarial critic pass on a different tier, prompted to refute, mechanical checks first, and a line logged to `~/.claude/autonomy-gates.jsonl`. Run the critic AFTER the unit returns and BEFORE merging its worktree. Do not use the parallel fleet itself as the critic: a panel is not a gate.
- **T3** — force pushes, prod deploys, data deletion, merges to main, outward-facing publishes, or anything touching a PR authored by or commented on by another person: never dispatched as a unit. Surface it, ask, and let the human decide.

A batch that mixes tiers runs at the highest tier present for its merge step, not the average.

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
- **Model tiering:** prefer omitting the `model` override so each unit inherits its agent definition's frontmatter tier (ADR-0049); pass an override only for a genuine one-off, and say why. When you do set it: write/port units → `sonnet`; mechanical doc/config units → `haiku`; critics/judges keep their agent-type default. Downgrade by default, subagents are background work: explore/audit/search units default to Haiku-or-local, and anything above Sonnet needs the reason stated in the dispatch. Apex tier (Fable first choice, Opus the fallback since 2026-07-08) is for the orchestrator's own reasoning, never routine execution.
- **Analysis-blocker refutation:** when an agent claims a library/API blocker ("crate doesn't export X"), scratch-compile a minimal probe BEFORE accepting — one refuted false blocker saved a whole unit from being stubbed.
