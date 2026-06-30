# Operator Harness Documentation

**Comprehensive reference guide for a fully-configured OpenCode / Claude Code operator environment with 325+ skills, 40+ agents, automated hook pipeline, RAG retrieval, memory persistence, and integrated MCP servers.**

> **Harnesses:** OpenCode (primary, `opencode.json`) → Claude Code (supported) → OpenRouter (fallback provider). The skill/agent/hook library is harness-agnostic and works across both.

---

## Quick Start: Daily Operations

### Starting a session

**OpenCode (preferred):**
```bash
opencode   # Opens OpenCode — reads opencode.json, routes via primary provider
```

**Claude Code (supported):**
```bash
claude   # Opens Claude Code CLI
```

**Fallback provider:** when the primary provider is rate-limited or unavailable, OpenCode routes through OpenRouter. Configure once with `opencode auth login openrouter` (set `OPENROUTER_API_KEY`).

The session start hook chain fires automatically:
- Auto-pulls latest state from `~/.claude-env`
- Reindexes any drifted RAG chunks
- Alerts if main branch has diverged
- Alerts if memory index is oversized

### Processing your first prompt
Every user prompt triggers `UserPromptSubmit` hooks (0-overhead):

1. **Auto-recall** — `autorecall-hook.sh` injects relevant docs as `# Knowledge graph context` block
2. **Model routing** — `model-tier-router.sh` routes to Haiku/Sonnet/Opus based on complexity
3. **Composite detection** — `composite-router.sh` emits `🎯 Composite match: /<name>` if your intent matches a composite skill
4. **Auto-context-pack** — if context >85%, automatically compacts context

### Most common daily patterns

| Task | Use This | Why |
|------|----------|-----|
| Start day, understand blocking work | `/session-bootstrap` | Chains wake-up → next-priority → pr-snapshot → context-pack |
| Plan before coding | `/plan` | Validation-gated plan for multi-step work |
| Implement independently-parallelizable tasks | `/dispatch` or `/orchestrate` | Fans out parallel agents, reconciles results |
| Review code before merge | `/code-review` | Severity-rated findings (bugs, regressions, security > style) |
| Debug a failing test or prod error | `/debug` | Systematic root-cause analysis |
| Full project health check | `/audit-deep` | Composites test, config, hooks, security, MCP, plugins |
| Refactor a module end-to-end | `/refactor-pipeline` | Chains plan → 3-agent team → test cleanup → ADR → docs-sync |
| Ship work + capture memory | `/session-wrap-up` | Chains ship → memory-sync → handoff |

### When to use composites vs. individual skills

**Always prefer composites** when the composite-router hook emits `🎯 Composite match`. Composites auto-chain phases and enforce gates. Running sub-skills manually bypasses critical phases.

Marked with `*` in skill lists below.

Example: User says "refactor this module."
- Correct: Composite-router fires `🎯 Composite match: /refactor-pipeline` → invoke `/refactor-pipeline`
- Wrong: Invoke `/refactor` directly, skipping discovery and plan phases

---

## Directory Structure

```
~/.claude/                              # Operator rules, hooks, state
├── CLAUDE.md                           # Global operator config
├── SKILLS.md                           # Skill index + descriptions
├── settings.json                       # Hook definitions + env config
├── settings.local.json                 # Local overrides + project-specific hooks
├── agents/                             # ~40 specialized agent definitions
├── hooks/                              # ~30 shell scripts for automation
├── memory/                             # Persistent memory database
├── handoffs/                           # Session checkpoint packets
├── plans/                              # Implementation plans
├── tasks/                              # Task tracker state
├── rag-index/                          # RAG retrieval + reindex hooks
├── workflows/                          # Saved Workflow() scripts
├── plugins/                            # Installed Claude Code plugins
├── templates/                          # Reusable artifact templates
├── standards -> ~/.agents/skills/standards/
└── skills -> ~/.agents/skills/

~/.agents/                              # Canonical skill and agent definitions
├── skills/                             # 325 skill folders
├── standards/                          # Policy and discipline docs (~20 files)
├── agents/                             # Agent definition mirrors
├── bin/                                # Utilities (sync binary)
├── memory/                             # Memory archive
└── scripts/

~/.claude-env/                          # Environment/bootstrap layer
├── bin/sync                            # Sync push/pull for memories + ADRs
├── adrs/                               # Architecture Decision Records
├── hooks/                              # Env-level hooks
└── ... (config, memory, scripts)

~/.config/opencode/                     # OpenCode portable default (mirrored by sharekit)
├── opencode.jsonc                       # Go primary + OpenRouter fallback + agent tiering
└── agents/                              # OpenCode agent overrides (architect, planner, critic, task)

~/.gjc/                                 # Gajae-Code portable default (mirrored by sharekit)
├── config.yml                          # Provider retry budgets (requestMaxRetries, streamMaxRetries, ...)
└── agents/                             # gjc role agent references (executor, architect, planner, critic)
```

### OpenCode + OpenRouter + Gajae-Code integration

`sharekit install` now mirrors two additional tool roots alongside `claude/` and `cursor/`:

- **`opencode/`** → `~/.config/opencode/`. Ships a portable `opencode.jsonc` with OpenCode Go (`opencode` provider) as the primary gateway and OpenRouter as the fallback (`options.provider.allow_fallbacks: true`). API keys are read from env vars (`OPENCODE_API_KEY`, `OPENROUTER_API_KEY`) — never hardcoded. Agent tiering mirrors the CLAUDE.md discipline: Sonnet-class for `build`/`architect`/`planner`/`critic`, Flash-class for `task`, cheapest for `title`. Analysis roles (architect, planner, critic) are read-only by construction (`permission: { edit: deny, bash: deny }`). This is a *portable default* — your personal `~/.config/opencode/opencode.jsonc` is left intact; OpenCode merges project + global configs.
- **`gjc/`** → `~/.gjc/`. Ships the documented `config.yml` retry budget (the user-facing config surface). gjc is an external runner that sits beside OpenCode/Claude Code and adds the `deep-interview → ralplan → ultragoal` workflow loop (optional `team` for parallel tmux workers). Model/provider selection in gjc uses a separate `models.yml` + `modelBindings` system; this profile intentionally does not override that. The four role-agent markdown files (`executor`, `architect`, `planner`, `critic`) are reference templates aligned with the operator's CLAUDE.md hard rules.

Both ship as **portable defaults**: installing this profile gives sane starting configs without clobbering personal overrides.

---

## Hook Lifecycle: What Fires When

Hooks are shell scripts wired to tool events. They are zero-overhead on success (exit 0 = silent), auto-killed at timeout (3-5s default), and logged on failure.

### SessionStart (fires once per session)
1. Log session start
2. Merge stale RAG chunks into live index
3. Pull latest memories + ADRs from env
4. Detect and reindex drifted files
5. Alert if main branch has drifted
6. Alert if memory index oversized

### UserPromptSubmit (fires on every prompt)
1. Auto-recall: semantic search, inject `# Knowledge graph context`
2. Classify prompt complexity (simple/moderate/complex/xcomplex)
3. Emit model tier hint (Haiku → Sonnet → Opus)
4. Log turn count
5. Warn if context >85%, suggest `/compact`
6. If intent matches composite: emit `🎯 Composite match: /<name>`
7. Warn if on release branch

### PreToolUse (safety gates)
- Filter dangerous bash (rm -rf, sudo rm, etc.)
- Block writes to protected paths
- Block re-reading same file twice

### PostToolUse (observe & learn)
- `[Bash]` → detect missed read-tool-kick opportunities
- `[Read]` → warn if >25KB, log which files read
- `[Write|Edit]` → reindex changed files
- `[*]` → log turn count, check token budget
- `[Edit]` → warn if >3 edits in one turn
- `[Write|Edit|MultiEdit]` → validate skill writes

### PreCompact / PostCompact / Stop / SessionEnd
- Pre/Post compact: snapshot state before/after compression
- Stop: log token usage, check rate limits
- SessionEnd: sync RAG and memories to persistent storage

### Enforcement & self-improvement (hook wiring)

Hooks are registered to lifecycle events in [`claude/settings.json`](claude/settings.json). Before that file existed, the `hooks/` scripts were orphan artifacts and 9 of 15 `RULES.md` "Must Always" rules were advisory-only. The registered events now enforce the protected invariants at runtime:

- `PreToolUse` (Bash) — `check-dangerous-patterns.sh` (destructive commands + sensitive paths), `check-pr-automation-halt.sh` (no force-push, no push to main, no AI-attribution in commits, halt on human-commented PRs), `check-stuck-loop.sh` (Stuck protocol), `check-idempotency.sh` (state-check-before-mutation hint). Exit 2 blocks.
- `PreToolUse` (Write/Edit) — idempotency hint (logged to trajectory).
- `SubagentStart` — `check-read-only-subagent.sh` blocks analysis subagents spawned with write tools (read-only-by-construction).
- `PostToolUse` — `trajectory-log.sh` appends every tool call to `.harness/runtime/trajectory.jsonl` (the observe half of the flywheel), then `context-guard.sh` writes compact digests for >2KB responses (tool-result firewall) + surfaces buried constraints (lost-in-the-middle audit), then `observe-otel.sh` emits a GenAI span + scans for context breaches.
- `PreCompact` / `PostCompact` — snapshot pre-compaction state + re-inject CORE memory so hard rules survive compaction.
- `Stop` — `post-incident-adr.sh` reminds on P0/P1 error spikes.
- `SessionEnd` — `session-end-flush.sh` writes a session record and queues it for the nightly distill.

The runtime log directory (`.harness/runtime/`) is gitignored — it is append-only fuel for the self-improvement loop, not source of truth. See [`docs/flywheel.md`](docs/flywheel.md) for the full observe → evaluate → optimize loop and [`claude/memory-structure/SELF_IMPROVEMENT.md`](claude/memory-structure/SELF_IMPROVEMENT.md) for the memory promotion ladder, staleness scoring, and nightly distill protocol.

### Self-improvement flywheel (evaluate half — P1)

The evaluate/optimize scripts that consume the trajectory log. They are run on-demand (or nightly via cron); none auto-mutate semantic memory — graduation is always host-agent-reviewed with required rationale.

- `hooks/distill.sh` — nightly distill: mines the trajectory log + pending queue, applies a heuristic prefilter and confidence-scoring (failure 1.0, learning 0.9, decision 0.8, pattern 0.7), stages candidates to `.harness/forge/`. Supports `--status`.
- `hooks/review.sh` — host-agent review CLI: `list`, `show <date>`, `graduate <id> --rationale "..."`, `reject <id> --reason "..."`, `reopen`, `decisions`. Graduation requires a rationale (no rubber-stamping) and writes staleness frontmatter.
- `hooks/eval-baseline.sh` — with-skill vs no-skill baseline gate: `init`, `record`, `compare`, `gate <name> <threshold>`. Gates on measurable lift (selftune `baseline` pattern).
- `hooks/diagnose.sh` — self-diagnosis: clusters failures in the trajectory log, detects repeated errors / tool overuse / blind retries / token-waste patterns (SkillForge + AHE Agent Debugger). Writes a digest + machine-readable clusters.
- `hooks/observe-otel.sh` — two-knob observability (pdhoolia): level (off/metrics/trace) + destination (jsonl/stderr/otel). GenAI semantic span names, context-breach scanning, idempotent ±1 feedback scores. Local JSONL by default.

### Self-improvement flywheel (optimize half — P2)

The optimize half closes the loop: a proposer reads the full non-Markovian iteration history, proposes evidence-backed edits, is gated, deployed, watched, and auto-reverted on regression. Contract copied from meta-agent / harness-evolver / hermes-evolution — NOT a dependency (no DSPy/GEPA/LangSmith).

- `hooks/history.sh` — the #1 lever: append-only iteration history store. Every proposal + eval result + WHY it failed is preserved so the proposer reads WHY prior attempts failed (non-Markovian full-history search beats best-of-N, per the meta-harness result). NEVER prunes. `why <target>` surfaces failure reasons.
- `hooks/propose.sh` — evolutionary proposer: assembles a non-Markovian proposal context (iteration history + diagnosis + distill candidates + current file content + gate checklist) for the proposing model to fill in. NEVER commits directly.
- `hooks/gate.sh` — constraint gate: tests pass, skill size ≤15KB, cache compatibility, semantic preservation (held-out eval lift ≥ 0), Pareto selection. The gate auto-runs the held-out bench via `eval-run.sh --gate-authority` before reading the lift, so it populates its own results — the proposer never authors the held-out runs (evaluator-not-agent invariant).
- `hooks/deploy-watch.sh` — auto-rollback: monitors post-deploy metrics, auto-backs-up before any revert, reverts to git HEAD on regression, records the regression in history so the proposer learns from it.
- `hooks/repo-map.sh` — bounded, cache-stable structural map (file tree + symbol index, ≤8KB) so the proposer targets edits without flooding context.

### Self-improvement flywheel (exercise the loop — P3)

P3 makes the loop runnable as one command, ships the last two context-engineering defenses (both advisory — they never block), and ships the concrete eval bench that turns the gate from a recording mechanism into a real measurement.

- `hooks/cycle.sh` — end-to-end cycle runner: chains diagnose → distill → propose → gate → report in a single command, skipping steps gracefully from a cold start. NEVER commits — it writes a cycle report the host agent reviews. `--dry-run` previews, `--status` re-reads the last report, `--target <file>` anchors the proposal. This is the command that makes the flywheel exercisable on demand or on a schedule.
- `hooks/tool-shortlist.sh` (UserPromptSubmit) — surfaces only the tools whose keywords match the prompt instead of the full catalog, cutting system-prompt context (contextweaver 92.2% route-prompt reduction, agentforge deferred-tools 60-70% cut). CLI: `suggest "<prompt>"`, `--status`.
- `hooks/model-cache-guard.sh` (UserPromptSubmit + PostCompact) — flags mid-conversation model switches as cache-unsafe (switching mid-stream discards the cached prompt prefix). The only cache-safe switch boundaries are first-turn and post-compaction (Copilot pattern). CLI: `--status`, `--reset`.
- `hooks/eval-tasks.sh` — deterministic eval task catalog: 20 harness-behavior tasks (synthetic tool-call event + expected verdict + owning hook) split into **seen** (proposer trains on) and **heldout** (gate evaluates on; proposer never sees the per-task expected verdicts). The split is the overfitting defense — a harness edit that hard-codes the seen cases fails on held-out. CLI: `list [--split seen|heldout|all]`, `show <id>`, `count [--split ...]`.
- `hooks/eval-run.sh` — A/B task runner: runs each task in with/without variants and records to `eval-baseline.sh`. `with` invokes the target hook and checks the exit code matches the expected verdict; `without` simulates the harness absent. Enforces the held-out split — refuses `--split heldout` unless `--gate-authority` is passed, which only `gate.sh` supplies (evaluator-not-agent invariant). CLI: `--eval <name> --variant with|without [--split seen|heldout|all] [--gate-authority]`.

### Self-improvement flywheel (convergent cross-cutting patterns — P4)

P4 layers the five convergent cross-cutting patterns the Wave-5 research tracks agreed on: context control, governance, temporal memory, progressive disclosure, and deterministic orchestration. Each is advisory-or-gated, never trust-the-model.

- `hooks/compaction-guard.sh` (PreCompact) — hybrid context control: audits tool-call/result adjacency preservation during compaction so execution drift cannot hide in a condensed window, threshold-triggered budget warnings, cache-prefix stability advisory. Advisory; never blocks.
- `hooks/policy-gate.sh` (PreToolUse) — deterministic governance layer: emits ALLOW/DENY/REQUIRE_APPROVAL verdicts from `mcp-policy.json` outside the model, appends each decision to a hash-chained tamper-evident ledger bound to context hash, exits 2 on DENY. CLI: `--verify` ledger integrity, `--status` verdict counts.
- `hooks/memory-consolidate.sh` — sleep-cycle memory consolidation: clusters related facts, finds supersede candidates, finds compression clusters, decays stale+low-confidence facts — all staged to `.harness/forge/` and never auto-applied. Extends the promotion ladder with bi-temporal validity windows; see [`claude/memory-structure/TEMPORAL_KG.md`](claude/memory-structure/TEMPORAL_KG.md). CLI: `--dir <path>`, `--status`.
- `hooks/skill-index.sh` — progressive-disclosure skill index: builds a metadata-only index of the skill catalog (name + description + triggers + size class, never bodies) so the host loads one skill body on demand instead of load-all. CLI: `--dir <path>`, `--status`.
- `hooks/skill-prune.sh` — telemetry-based skill pruning: reads the trajectory and stages never-hit / low-hit skills as archive candidates. Archive, never `rm`. CLI: `--dir <path>`, `--status`.
- `hooks/dispatch.sh` — deterministic orchestration substrate: a fixed state machine (intake → triage → plan → research → implement → review_gate → eval → merge_gate → done, with BLOCKED first-class) where no LLM decides what fires next. Bounded workers (including the P2 proposer/evaluator) execute steps; the substrate owns transitions and the two human-in-the-loop gates. See [`docs/handoff-schema.md`](docs/handoff-schema.md). CLI: `--intake`, `--advance`, `--block`, `--allow-gate`, `--status`, `--list`.

### Self-improvement flywheel (target architecture — P5)

P5 is the integration target: the flywheel from P0-P2 + the convergent patterns from P4, operating as a single closed loop. `hooks/cycle.sh` now exercises the whole architecture as one command, with two tracks run in sequence:

- **TRACK A — MAINTAIN** (the P4 substrate, periodic hygiene): `memory-consolidate.sh` (sleep-cycle), `skill-index.sh` (progressive-disclosure index), `skill-prune.sh` (telemetry-based archive candidates). Advisory; stages reports, never auto-applies.
- **TRACK B — IMPROVE** (the P0-P3 flywheel, routed via `dispatch.sh`): `diagnose.sh` → `distill.sh` → `propose.sh` (at dispatch `implement` → `review_gate`) → `gate.sh` (at `eval`, with the held-out eval set the proposer never saw). On gate pass, dispatch advances to `merge_gate`; on regression, dispatch parks BLOCKED so the proposer reads WHY next time.

The cycle closes the evaluate→optimize loop through the deterministic substrate — never trusting the model to self-route or self-promote. See [`docs/target-architecture.md`](docs/target-architecture.md) for the five load-bearing subsystems and the eight load-bearing invariants. CLI: `--target <file>`, `--eval <set>`, `--dry-run`, `--status`, `--no-maintain`.

---

## Agents: Specialized Worker Types

~40 agent types for different tasks. Invoke via Agent tool or skills that dispatch them.

**Analysis agents** (read-only): architect, code-reviewer, critic, decision-critic, document-specialist, efficiency-advisor, explore, scientist, security-reviewer

**Execution agents** (write files): backlog-manager, ci-fixer, code-simplifier, debugger, deep-auditor, designer, git-master, handoff-writer, issue-triager, mcp-tool-dev, mutation-tester, parallel-implementer, phase-runner, pr-reviewer, rag-evaluator, refactor-orchestrator, research-decider, systematic-debugger, tdd-practitioner, team-coordinator, test-engineer, tracer, writer, xp-navigator

**Forge ecosystem**: ecosystem-coordinator, forge-patterns-expert, mcp-gateway-specialist, uiforge-mcp-architect, webapp-developer

See `~/.claude/agents/` for full definitions.

---

## Skills: 325 Total Across 18 Categories

Skills are autonomous entry points. See `~/.claude/SKILLS.md` for complete reference.

**Session & Context** (10): wake-up, session-bootstrap*, resume, context-pack, handoff, session-wrap-up, session-cleanup, etc.

**Planning & Execution** (14): plan, route, next-priority, loop, dispatch, orchestrate, add, scope-and-execute*, parallel-phases*, feature-from-zero*, fallback

**Code Quality** (14): code-review, refactor, refactor-plan, refactor-pipeline*, verify, verify-before-done*, quality-gates, impeccable, simplify

**Testing** (12): tdd, test-health, test-cleanup, generate-tests, coverage-gap, mutation-test, fix-the-suite*, webapp-testing, playwright-best-practices

**Debugging** (6): debug, debug-deep*, systematic-debugging, diagnosing-bugs

**Security** (7): secure, security-audit, security-sweep, semgrep, harness-audit, audit-deep*

**Git & PR** (11): pr-flow, pr-merge-readiness, pr-snapshot, branch-hygiene, merge-confidently, hotfix, version-bump, release-cut, gh-fix-ci

**Ship & Deploy** (4): ship, ship-it, vercel-deploy, cloudflare-deploy

**RAG & Memory** (15): recall, adt-rag, rag-quality, sync-memories, memory-prune, knowledge-loop*, adt-memory, mem-search

**Architecture & ADRs** (10): adr-write, adr-gap, architecture-patterns, codebase-design, domain-modeling, coupling-map, orphan-hunt, graphify

**Repository Management** (11): onboard-new-repo*, adt-repo-intake, backlog*, triage, to-issues, to-prd, ecosystem-health, repo-state-snapshot

**CI/CD** (3): ci-watch, dep-sweep*, adt-schedule

**Observability** (8): observe, sentry, langfuse-observe, observability-bootstrap*, observability-audit*

**MCP & Plugins** (8): mcp-audit, mcp-care*, mcp-builder, adt-mcp-health, hook-effectiveness, plugin-audit

**AI & Agents** (10): ai-sdk, smart-model-select, agent-browser, adt-eval, adt-multi-agent, efficiency-advisor

**Skills & Plugin Management** (8): skill-creator, skill-maintainer, skill-effectiveness-audit, docs-sync, find-skills

**Performance & Cost** (6): token-audit, smart-commands, rate-limit-watch, mac-optimize, insights, metrics

**Standards & Research** (7): research-and-decide, adt-research, standards, adt-plan-change, automation-workflows, brainstorming

*= composite (auto-chains sub-skills)

---

## MCP Servers

### Local
- **rag-index** — semantic search on local knowledge base
- **tavily** — web search
- **fetch** — fetch URLs
- **firecrawl** — web scraping/crawling
- **sonarqube** — code quality analysis
- **graphify** — knowledge graph queries

### Cloud (via claude.ai)
Context7, Gmail, Google Calendar, Google Drive, Hugging Face, Jam, Linear, Sentry, Vercel, Cloudflare, GitHub, Playwright, Supabase, Serena, codebase-memory-mcp, filesystem, claude-mem

---

## Plugins Installed

Vercel, GitHub, Firecrawl, Supabase, CodeRabbit, Skill Creator, Claude Code Setup, Claude MD Management, Claude Mem, LLM Docs Optimizer, Plugin Dev

Each plugin extends Claude Code with new skills and tool integrations.

---

## Standards & Policies

Key policy documents in `~/.agents/skills/standards/`:

- **agent-routing.md** — when to use which agent type, read-only enforcement
- **composite-contract.md** — composite-first principle, bail-out detection
- **pr-conventions.md** — PR title/body/attribution standards
- **graphify-discipline.md** — graph-first token discipline
- **decision-discipline.md** — research-before-deciding rules
- **artifact-schema.md** — structured artifact formats
- ... (14+ more policy docs)

---

## Configuration

### Model Tiering
- **Main loop:** Sonnet 4.6 (execution default)
- **Subagents:** Haiku 4.5 (mechanical tasks, fast)
- **Opus:** Explicitly invoked for complex reasoning, ADR writing
- **Autocompact:** 85% context threshold

### Hard Rules (Non-Negotiable)
1. Never automate on PRs with human reviewer comments
2. Parallel execution mandatory for ≥2 independent tasks (use worktrees for same-repo)
3. Analysis subagents read-only by agentType, not just prompt
4. No big-bang rewrites without demand measurement gate
5. Idempotency: state-check before mutation
6. Dispatcher ≠ executor boundary (no logic in orchestrators)
7. Repository as single source of truth
8. No Claude co-author attribution on commits/PRs
9. Storage on External HD (/Volumes/External HD/Desenvolvimento/)
10. Stuck protocol: >2 attempts without progress → surface, switch approach, escalate

### Default Behaviors
- **Caveman mode ON** — terse, drop filler, keep technical substance
- **Skill-first execution** — skills invoked autonomously when matching
- **Composite-first** — composite-router detects intent, emits `🎯 Composite match: /<name>`
- **Graph-first token discipline** — query graph before file reads
- **Signal-first output** — verdict + top-3 findings; "X more — ask for full list" if >3

---

## Optimal Usage Patterns

### Daily Workflow
```
1. /session-bootstrap (chains: wake-up → next-priority → pr-snapshot → context-pack)
2. /plan (for complex work) or /route (if unsure)
3. /dispatch or /orchestrate (≥2 independent tasks) or /loop (single task)
4. /code-review + /verify-before-done* (before merge)
5. /session-wrap-up (ship → memory-sync → handoff)
```

### Using Composites
When composite-router emits `🎯 Composite match: /<name>`: invoke that composite. Running sub-skills manually skips critical phases.

| Task | Use Composite | Why |
|------|---------------|-----|
| Refactor a module | `/refactor-pipeline*` | Enforces plan → team → test-cleanup → ADR phases |
| Onboard repo | `/onboard-new-repo*` | Chains intake → audit → config-drift → CLAUDE.md |
| Build feature from scratch | `/feature-from-zero*` | Full greenfield: research → scope → design → test → merge → ship |
| Health check | `/audit-deep*` | Parallel sub-agents across 7 dimensions |
| End session | `/session-wrap-up` | Chains ship → memory → handoff |

### Model Selection
- **Haiku:** Mechanical tasks (formatting, symbol lookup, grep, simple renames), subagent batch work
- **Sonnet (default):** Implementation, feature work, code review, test generation
- **Opus:** Orchestration, critic role, architectural decisions, ADR writing

Use `smart-model-select` before multi-agent work. Never override for speculative speed.

### Parallel Execution
For ≥2 independent units (parallel investigations, multi-repo sweeps, batch fixes):
1. Dispatch one Agent per unit in SINGLE tool-use block
2. Use worktrees if same repo: `/Volumes/External HD/Desenvolvimento/.worktrees/<task>-<n>/`
3. Set correct `agentType` (Explore for analysis, general-purpose for execution)
4. Use `parallel()` or `pipeline()` in Workflow scripts

### Context Management
- **Auto-compaction:** At 85% fill, `auto-context-pack.sh` warns + suggests `/compact`
- **Read dedup:** `read-dedup.sh` blocks re-reading same file twice
- **RTK detection:** `rtk-miss-detector.sh` flags Bash that should use Read tool
- **Large file warning:** >25KB read emits warning

If context bloat builds: `/compact` (saves ~30-40% tokens)

### Token Optimization
| Goal | Skill | What it does |
|------|-------|--------------|
| ~75% token compression | `/caveman` | Drops filler/articles/pleasantries while keeping full technical accuracy. Persists until toggled off. |
| Minimal solutions | `/ponytail` | Forces simplest, shortest, most minimal solution (YAGNI, stdlib before deps, one line before fifty). |
| Audit repo for bloat | `/ponytail-audit` | Whole-repo audit for over-engineering — ranked list of what to delete/simplify. |
| Lint a diff for complexity | `/ponytail-review` | Review focused exclusively on over-engineering in a diff. |
| Track deferred shortcuts | `/ponytail-debt` | Harvest `ponytail:` comments into a tracked debt ledger. |
| Historical token spend | `/token-audit` | Analyze Claude Code session JSONLs — spend, cache hit rates, weekly trends. |
| Context bloat | `/optimize-context` | Reduce token consumption when context is bloated or responses are slow. |
| Load only relevant context | `/context-pack` | Build a task-aware context bundle before large changes or unfamiliar work. |

### Knowledge-Brain & RAG
The profile ships a **Megabrain** system: one vault for all projects (memory + graphs + RAG).

| Goal | Skill | What it does |
|------|-------|--------------|
| Semantic lookup | `/recall` | One-shot lookup against the local RAG index (~21k chunks across memory, plans, handoffs, skills, code). |
| Code → knowledge graph | `/graphify` | Turn code/docs/papers/images into a knowledge graph for structural queries. |
| Structural code queries | `/codebase-memory` | Knowledge graph for call chains, dead code, fan-out, impact analysis. |
| New project brain | `/bootstrap-project` | Stand up a new project's memory + central graph in one ritual. |
| RAG index audit | `/rag-maintenance` | Full pipeline: quality → coverage → drift → curate. |
| Retrieval quality | `/rag-quality` | Evaluate retrieval quality from the local RAG index. |
| Corpus coverage gaps | `/adt-rag-coverage` | Audit corpus distribution by source type; find under-indexed topics. |
| Stale chunks | `/adt-rag-drift` | Detect and fix stale chunks (files changed/deleted since indexing). |
| Improve weak chunks | `/rag-curate` | Add missing docs, rewrite weak chunks, fill retrieval gaps. |
| Retrieval regression gate | `/rag-eval` | Hit@5/MRR regression gate against a frozen baseline. |

---

## Troubleshooting

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| Hooks not firing | `cat ~/.claude/tool-failures.log \| jq '\[\]'`; verify settings.json | Increase timeout, debug hook directly, check dependencies |
| Composite not invoked | Check session.log for `Composite match`; verify intent matches skill | Invoke directly: `/composite-name` |
| RAG retrieval stale | `/adt-rag-coverage` and `/adt-rag-drift` scan for gaps | Reindex: `/adt-rag-index-rebuild` |
| Agent spawn failed | Verify agent exists: `ls ~/.claude/agents/ \| grep name` | Use default agent or check agent file syntax |
| Memory not persisting | Check sync: `cat ~/.claude/.sync.log \| tail` | `/sync-memories` explicitly; verify frontmatter |
| Slow hooks / timeouts | `time bash ~/.claude/hooks/name.sh` | Increase timeout in settings.json or optimize hook |
| Parallel agents conflicting | Verify worktrees: `ls /Volumes/External\ HD/Desenvolvimento/.worktrees/` | Ensure `isolation: "worktree"` on agents |
| Token budget hit | `/token-audit` for analysis | `/compact` for relief; `/update-config` to raise limit |

---

## Getting Help

- **Skill reference:** `/find-skills <keyword>` or browse `~/.agents/skills/`
- **Policy questions:** Check `~/.agents/skills/standards/` for decision rules
- **Hook debugging:** `cat ~/.claude/tool-failures.log \| jq`
- **Token analysis:** `/token-audit` for weekly spend review
- **System health:** `/audit-deep*` for full project + harness check
- **Stuck:** `/route` to disambiguate intent or `/fallback` to recover

---

**Last updated:** 2026-06-29  
**Harness version:** Agent-OS (v6+), 325 skills, 40+ agents, 34 hooks, 6 MCP servers
