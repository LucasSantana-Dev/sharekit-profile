# Agent and Skill Routing

Use specialized skills or agents intentionally.

- Use lightweight routing for lookup, search, and triage.
- Use the normal implementation path for scoped coding work.
- Use deeper reasoning only for architecture, security, migration, or hard debugging.
- Route before you sprawl the main context.
- Prefer one primary workflow at a time UNLESS the work has 2+ independent units, then parallel dispatch is mandatory (see below).

## Mandatory subagent dispatch

This section governs WHEN you must dispatch subagents instead of working in the main context. The one parallel rule lives in [workflow.md § Parallel execution](workflow.md#parallel-execution-mandatory): dispatch when the work has 2+ independent units; the only exemption is the inline exemption below. This section adds routing only.

### Hard triggers — dispatch one `Agent()` per unit, in a single tool-use block

| Trigger | Agent type | Worktree? |
|---|---|---|
| Search across N repos / N directories | `Explore` × N | No (read-only) |
| Audit N repos for health / security / drift | `general-purpose` or domain-specialist × N | **Yes** — one per repo |
| Apply same fix to N files in same repo | `general-purpose` × N | **Yes** — one per agent |
| Review N PRs or N independent changes | `code-reviewer` × N | No (read-only) |
| Multi-perspective review of one change | `critic` + `security-reviewer` + `code-reviewer` in parallel | No |
| Investigate N hypotheses for one bug | `tracer` × N (read-only); `debugger` × N is write-capable | No for `tracer`, **Yes** for `debugger` |
| Run N independent diagnostics | matching specialist × N | No (read-only) |
| Generate N independent components / files | `general-purpose` × N | **Yes** — one per agent |

### Worktree rule

A worktree is required only for write-capable agents when 2+ agents touch the same repo: one each, at `${DEV_ROOT}/.worktrees/<task>-<n>/`. Read-only agents (`Explore`, `Plan`, `critic`, `code-reviewer`, `security-reviewer`, `document-specialist`, `explore`) share the checkout, unless they run builds, tests or index-locking git commands, in which case they get a worktree too. In the table above, "Worktree? Yes" means this rule applies to write-capable agents.

### Read-only enforcement for analysis phases

Analysis-class subagents — research, triage, spec, audit, review, investigation: anything that returns findings / specs / recommendations rather than code changes — MUST be dispatched with a **write-incapable `agentType`** so editing is structurally impossible, never merely requested in the prompt. A prompt that says "read-only, return findings" is NOT enough — agents have repeatedly written to disk anyway despite it.

- Use a write-incapable type: `Explore`, `explore`, `Plan`, `critic`, `code-reviewer`, `security-reviewer`, or `document-specialist` (none have Edit/Write).
- In `Workflow`, set `agentType:` on the `agent()` call for **every** analysis stage. Only implementation/fixer stages get a write-capable type (`general-purpose`, `debugger`, `test-engineer`, …).
- Belt-and-suspenders, not a substitute: still write "READ-ONLY: do not edit/write/create any file; return findings only" in the prompt.
- If an analysis agent's output must drive edits, the ORCHESTRATOR applies them — or a separate write-capable implementer stage does — never the analysis agent itself.

### Inline-execution exemption

Stay in the main context only when the whole task is under 3 reads and under 2 edits, or the combined expected output is under ~5k tokens. Also inline: single-unit work, strict data dependency (B needs A's output), conversational turns with no tool work, or the user says "just do it inline" / "no subagents".

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

Every agent definition in `~/.claude/agents/*.md` frontmatter MUST set an explicit `model:` field, no agent inherits a model implicitly. This is the primary lever for model-tier cost control (subagent dispatch is the one place a model choice can be set programmatically; the main-session model can only be changed via `/model`, never by a hook). Tier per standards/model-tiering.md: Fable (apex, architecture/critic-of-critical/consequential ADRs), Opus (fallback, composite orchestration entrypoints, standard critic, routine ADR writing), Sonnet (execution and mechanical work, default); Haiku is retired (2026-09-17). When dispatching `Agent()`/`Workflow() agent()` calls, prefer omitting the `model` override so the call inherits the agent definition's frontmatter tier; only pass an explicit override for a genuine one-off exception, and note why.

### Downgrade-by-default (2026-08-04, from the router's background-task downgrade pattern)

Subagents are background work — dispatch them ONE TIER BELOW your first instinct. Upgrade only with an explicit reason ("cross-file synthesis", "adversarial critic", "touches auth"). Concretely: explore/audit/search agents default Sonnet; implementation agents default Sonnet; Opus+ requires the reason stated in the dispatch. The router downgrades background tasks automatically; the harness does it by discipline.

## Active agents (post-2026-05-02 consolidation)

- **Planning**: `planner` (interview-driven), `critic` (multi-perspective review). Use `critic` for architecture/code-quality second opinions.
- **Investigation**: `tracer` (causal hypotheses), `debugger` (root-cause + stack traces), `explore` / `Explore` (codebase search), `Plan` (implementation plans).
- **Implementation**: main agent by default for single-unit work. Delegate to focused subagents for parallel work or context protection.
- **Testing**: `test-engineer` (strategy + flaky tests), `qa-tester` (interactive CLI via tmux).
- **Review**: `code-reviewer`, `security-reviewer`, `code-simplifier`.
- **Specialized**: `git-master`, `designer`, `writer`, `document-specialist`, `mcp-tool-dev`, `scientist`, `general-purpose`.

Archived (`~/.claude/agents-archive/`): `analyst` → use `planner`; `architect` → use `critic`; `executor` → use main agent; `verifier` → use `test-engineer` + `verify` skill.
