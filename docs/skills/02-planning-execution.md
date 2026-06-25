# Planning & Execution Skills

Use when scoping work before touching code. `plan` for any non-trivial task; `route` when unsure which skill fits; `dispatch`/`orchestrate` when work decomposes into independent parallel tracks. `loop` is the default execution heartbeat.

---

## /plan

Build a compact, validation-gated implementation plan for multi-step, risky, or ambiguous work.

**When to use:** Before implementing anything non-trivial; when scope is unclear; when risk is high

**Produces:**
- Sequenced steps with dependencies
- Rollback identification
- Verification criteria per step
- File paths + line ranges (if applicable)

**Output:** Phased plan + validation gates

---

## /route

Decide the right skill, agent, or chain for the current request before spending tokens on the wrong path.

**When to use:** Unsure which skill to invoke; request seems to match multiple skills; ambiguous intent

**Analyzes:**
- Request intent + scope
- Available skills + composites
- Prior similar work (via RAG)
- Recommended entry point

**Output:** Recommended skill + reasoning

---

## /next-priority

Decide the highest-value safe thing to do right now in the active repo or workspace.

**When to use:** Start of day; end of sprint; after PR merge

**Considers:**
- Blocking work (failing tests, unmerged PRs)
- Customer impact (open bugs vs. features)
- Technical debt (test health, security)
- Estimated effort vs. impact

**Output:** Ranked list of next actions (1-3 items)

---

## /loop

Default execution rhythm — inspect → act → verify → checkpoint — applied iteratively until done.

**When to use:** Single-threaded task; incremental progress

**Cycle (repeats until done):**
1. **Inspect:** Assess current state
2. **Act:** Take one focused action
3. **Verify:** Confirm action worked
4. **Checkpoint:** Save progress (commit, memory, handoff)

**Output:** Completed task via iterative cycles

---

## /dispatch

Split cleanly separable investigation work into parallel tracks, then reconcile results.

**When to use:** Work has 2+ independent sub-investigations (e.g., "audit 3 repos in parallel")

**Process:**
1. Decompose into independent units
2. Dispatch one Agent per unit in SINGLE tool-use block
3. Collect results
4. Reconcile findings

**Output:** Combined investigation results

---

## /orchestrate

Coordinate multi-agent teams, multi-step or multi-repo work across plans, skills, worktrees, and parallel investigations.

**When to use:** Work spans multiple repos, multiple phases, or needs complex coordination

**Manages:**
- Parallel execution (worktrees for same-repo isolation)
- Dependency ordering
- Barrier points + verification
- State sharing between agents

**Output:** Orchestrated team results

---

## /add

Add a feature, test, config, doc, or automation safely with clear scope and validation.

**When to use:** Adding one focused thing (not refactoring or fixing)

**Process:**
1. Define scope (what goes in, what stays out)
2. Identify dependencies
3. Implement with validation
4. Test + verify

**Output:** Added feature + verified

---

## /scope-and-execute ⭐ **Composite**

Understand a problem, plan the work, execute it, and ship it in one chained workflow.

**Phases:**
1. **Understand:** Problem statement, constraints, success criteria
2. **Plan:** Implementation plan with rollback
3. **Execute:** Follow plan + verify each step
4. **Verify:** Run pre-ship gates
5. **Ship:** Merge + deploy

**When to use:** "Build X / fix Y / refactor Z" with unclear scope

**Output:** Completed, shipped work

---

## /parallel-investigate

Fan out N independent investigations as parallel agents in a single tool-use block, then roll up results.

**When to use:** 3+ independent questions to answer in parallel

**Process:**
1. Define each investigation
2. Dispatch parallel agents (one tool-use block)
3. Collect results
4. Synthesize findings

**Output:** Rolled-up investigation results

---

## /parallel-phases ⭐ **Composite**

Take a phased plan with independent tasks per phase, fan out agents per wave, gate between phases.

**When to use:** Plan has independent tasks per phase; need parallel execution

**Process:**
1. **Phase 1:** Fan out N agents in parallel
2. **Reconcile Phase 1:** Verify all tasks complete
3. **Gate:** Verify before proceeding (manual or automated)
4. **Phase 2:** Fan out next wave
5. Repeat

**Output:** Completed phases + phase × outcome report

---

## /subagent-driven-development

Execute implementation plans with independent tasks using parallel subagents.

**When to use:** Implementation plan with many independent tasks

**Process:**
1. Dispatch one subagent per task (parallel, same tool-use block)
2. Each subagent executes its task
3. Reconcile results
4. Identify any blockers

**Output:** Implemented tasks + reconciliation

---

## /feature-from-zero ⭐⭐ **Mega-Composite**

Full greenfield feature development from idea to live: research → scope → design → test → merge → ship.

**Phases:**
1. **Research:** Similar features, tech choices, patterns
2. **Scope:** MVP definition + success criteria
3. **Design:** Interface + data model
4. **Implement:** TDD (test-first)
5. **PR:** Open PR + review cycle
6. **Merge:** Merge to main
7. **Ship:** Tag + deploy

**When to use:** Building a new feature from scratch

**Output:** Live feature with full history

---

## /fallback

Recover cleanly when the preferred tool, skill, or path fails.

**When to use:** Skill returns "out of scope", agent fails, tool unavailable

**Process:**
1. Identify why preferred path failed
2. Propose alternative approach
3. Execute fallback
4. Learn from failure (memory + improvements)

**Output:** Work completed via fallback path + failure analysis

---

**Last updated:** 2026-06-25
