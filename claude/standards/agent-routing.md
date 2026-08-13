# Agent and Skill Routing

Use specialized skills or agents intentionally.

- Use lightweight routing for lookup, search, and triage.
- Use the normal implementation path for scoped coding work.
- Use deeper reasoning only for architecture, security, migration, or hard debugging.
- Route before you sprawl the main context.
- Prefer one primary workflow at a time UNLESS the work decomposes into ≥2 independent units — then parallel is mandatory (see below).

## Mandatory subagent dispatch

This section governs WHEN you must dispatch subagents instead of working in the main context. The detailed criteria live in [workflow.md § Parallel execution](workflow.md#parallel-execution-mandatory); this is the routing-side enforcement.

### Hard triggers — dispatch one `Agent()` per unit, in a single tool-use block

| Trigger | Agent type | Worktree? |
|---|---|---|
| Search across N repos / N directories | `Explore` × N | No (read-only) |
| Audit N repos for health / security / drift | `general-purpose` or domain-specialist × N | **Yes** — one per repo |
| Apply same fix to N files in same repo | `general-purpose` × N | **Yes** — one per agent |
| Review N PRs or N independent changes | `code-reviewer` × N | No (read-only) |
| Multi-perspective review of one change | `critic` + `security-reviewer` + `code-reviewer` in parallel | No |
| Investigate N hypotheses for one bug | `tracer` × N or `debugger` × N | No (read-only) |
| Run N independent diagnostics | matching specialist × N | No (read-only) |
| Composite phase with ≥3 independent tasks | via `/parallel-phases` | Yes if writing |
| Generate N independent components / files | `general-purpose` × N | **Yes** — one per agent |

### Worktree rule (when 2+ parallel agents touch the same repo)

EVERY parallel agent that reads or writes the same repo gets its own worktree at `${DEV_ROOT}/.worktrees/<task>-<n>/`. No exceptions for "small" edits — git index contention is silent and corrupting.

Read-only agents (`Explore`, search-only `general-purpose`) can share a checkout because they don't touch the index. Anything that runs `git`, edits files, or invokes test/build commands gets its own worktree.

### Read-only enforcement for analysis phases

Analysis-class subagents — research, triage, spec, audit, review, investigation: anything that returns findings / specs / recommendations rather than code changes — MUST be dispatched with a **write-incapable `agentType`** so editing is structurally impossible, never merely requested in the prompt. A prompt that says "read-only, return findings" is NOT enough — agents have repeatedly written to disk anyway despite it.

- Use a write-incapable type: `Explore`, `explore`, `Plan`, `critic`, `code-reviewer`, `security-reviewer`, or `document-specialist` (none have Edit/Write).
- In `Workflow`, set `agentType:` on the `agent()` call for **every** analysis stage. Only implementation/fixer stages get a write-capable type (`general-purpose`, `debugger`, `test-engineer`, …).
- Belt-and-suspenders, not a substitute: still write "READ-ONLY: do not edit/write/create any file; return findings only" in the prompt.
- If an analysis agent's output must drive edits, the ORCHESTRATOR applies them — or a separate write-capable implementer stage does — never the analysis agent itself.

### Inline-execution exceptions

Stay in the main context (don't dispatch) when:

- Single unit of work.
- Total scope is <3 file reads AND <2 edits.
- Strict data dependency (unit B's input is unit A's output).
- Conversational / decision-making turns (no tool work).
- User explicitly says "just do it inline" or "no subagents".

### Refusal pattern

If a user request matches a hard trigger and you start executing inline anyway, stop after the first unit, re-dispatch the rest as parallel `Agent()` calls, and surface the correction. Sequential execution of independently-parallelizable work violates the CLAUDE.md hard rule.

## Subagent token economics (measured 2026-08-03, router-dissection session)

Subagent cost is dominated by (a) what agents READ and (b) what they RETURN. Two 8-agent thorough sweeps produced 136KB + 183KB of reports that were then paged into main context — the failure mode this section prevents.

Briefing rules (every `Agent()`/`AgentSwarm()` prompt):

1. **Cap the report**: every brief ends with a hard output budget — default "report ≤200 lines: findings with file:line refs, no essays". Deep dissections get ≤400. Agents with no cap write essays.
2. **Grep-first briefs**: name the load-bearing files to read fully (you locate them first with Glob/Grep); instruct "grep/skim everything else, full-read only these N files". Never write "read every file fully" for repos with god-files.
3. **Thoroughness default is `medium`**. `thorough` only when the question genuinely spans the whole repo. One agent per question-class or repo — not per file-group — unless the scope is huge.
4. **Recall before dispatch**: run `recall`/`search_knowledge`/`ctx_search` first. If the answer exists in memory or a prior indexed report, no agent is needed at all.
5. **Resume over respawn**: failed/timed-out agents keep context — `resume` them. A 403/quota failure means STOP spawning, not retry the whole swarm.

Main-context rules (what to do with returns):

6. **Index, don't page**: any agent output >50KB → `ctx_index` it immediately, then pull answers with `ctx_search`. Never Read-page a >50KB tool result into main context just to summarize it.
7. **Derive in sandbox**: counts/filters/aggregations over files or logs → `ctx_execute`/`ctx_execute_file`; only the printed answer enters context.
8. **Structured verdicts over prose**: ask for findings lists (severity, file:line, one-line evidence), not narrative reports.

Anti-pattern registry (do not repeat): 8 thorough agents told to read a 5017-line god-file in full; paging 183KB through Read to synthesize; re-running a swarm after a provider quota 403.

## Model tier enforcement (ADR-0049)

Every agent definition in `~/.claude/agents/*.md` frontmatter MUST set an explicit `model:` field — no agent inherits a model implicitly. This is the primary lever for model-tier cost control (subagent dispatch is the one place a model choice can be set programmatically; the main-session model can only be changed via `/model`, never by a hook). Tier per CLAUDE.md's Model tiering section: Fable (apex — architecture/critic-of-critical/consequential ADRs), Opus (fallback — composite orchestration entrypoints, standard critic, routine ADR writing), Sonnet (execution — default), Haiku (mechanical — lookups, formatting, transcription). When dispatching `Agent()`/`Workflow() agent()` calls, prefer omitting the `model` override so the call inherits the agent definition's frontmatter tier; only pass an explicit override for a genuine one-off exception, and note why.

### Downgrade-by-default (2026-08-04, from the router's background-task downgrade pattern)

Subagents are background work — dispatch them ONE TIER BELOW your first instinct. Upgrade only with an explicit reason ("cross-file synthesis", "adversarial critic", "touches auth"). Concretely: explore/audit/search agents default Haiku-or-local; implementation agents default Sonnet; Opus+ requires the reason stated in the dispatch. The router downgrades background tasks automatically; the harness does it by discipline.

## Active agents (post-2026-05-02 consolidation)

- **Planning**: `planner` (interview-driven), `critic` (multi-perspective review). Use `critic` for architecture/code-quality second opinions.
- **Investigation**: `tracer` (causal hypotheses), `debugger` (root-cause + stack traces), `explore` / `Explore` (codebase search), `Plan` (implementation plans).
- **Implementation**: main agent by default for single-unit work. Delegate to focused subagents for parallel work or context protection.
- **Testing**: `test-engineer` (strategy + flaky tests), `qa-tester` (interactive CLI via tmux).
- **Review**: `code-reviewer`, `security-reviewer`, `code-simplifier`.
- **Specialized**: `git-master`, `designer`, `writer`, `document-specialist`, `mcp-tool-dev`, `scientist`, `general-purpose`.

Archived (`~/.claude/agents-archive/`): `analyst` → use `planner`; `architect` → use `critic`; `executor` → use main agent; `verifier` → use `test-engineer` + `verify` skill.
