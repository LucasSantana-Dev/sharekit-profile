# Operator Harness Documentation

**Comprehensive reference guide for a fully-configured OpenCode / Claude Code operator environment with 52 skills, 40+ agents, automated hook pipeline, RAG retrieval, memory persistence, and integrated MCP servers.**

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
| Review code before merge | `/review` | Severity-rated findings (bugs, regressions, security > style) |
| Debug a failing test or prod error | `/debug` | Systematic root-cause analysis |
| Full project health check | `/quality-assurance` | Composes tests, config, hooks, security, MCP, and release evidence |
| Refactor a module end-to-end | `/request-refactor-plan` → `/orchestrate` | Plans, fans out bounded work, validates, and captures decisions |
| Ship work + capture memory | `/ship` + `/knowledge-loop` | Releases work, syncs memory, and writes handoff when needed |

### When to use composites vs. individual skills

**Always prefer composites** when the composite-router hook emits `🎯 Composite match`. Composites auto-chain phases and enforce gates. Running sub-skills manually bypasses critical phases.

Marked with `*` in skill lists below.

Example: User says "refactor this module."
- Correct: use `/request-refactor-plan` for scope/rollback, then `/orchestrate` or `/three-man-team` when parallel implementation is justified.
- Wrong: invoke `/refactor` directly for a broad module rewrite, skipping discovery and validation.

---

## Directory Structure

```
~/.claude/                              # Operator rules, hooks, state
├── CLAUDE.md                           # Global operator config
├── SKILLS.md                           # Skill index + descriptions
├── settings.json                       # Hook definitions + env config
├── settings.local.json                 # Local overrides + project-specific hooks
├── agents/                             # ~40 specialized agent definitions
├── hooks/                              # 42 shell scripts for automation
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
├── skills/                             # 52 skill folders
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
- `hooks/transcript-scanner.sh` (P8.3) — post-hoc transcript scanners (inspect-ai): scans the trajectory for systemic patterns per-task evals miss — refusals, evaluation-awareness, environment-drift, hallucination signals, excessive-agency, prompt-injection tells. Complements `diagnose.sh` (failure clustering). Stages findings to `.harness/forge/`; never blocks. CLI: `--since <iso>`, `--status`.
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
- `hooks/skill-index.sh` — progressive-disclosure skill index: builds a metadata-only index of the skill catalog (name + description + triggers + invocation_type + allow_implicit + size class, never bodies) so the host loads one skill body on demand instead of load-all. Skills with `invocation_type=slash` are excluded from auto-invocation; skills with `allow_implicit=false` (🔒) require explicit confirmation even on trigger match. CLI: `--dir <path>`, `--status`.
- `hooks/skill-prune.sh` — telemetry-based skill pruning: reads the trajectory and stages never-hit / low-hit skills as archive candidates. Archive, never `rm`. CLI: `--dir <path>`, `--status`.
- `hooks/skill-validate.sh` — frontmatter schema + security validation gate: validates all SKILL.md files for schema compliance (name ≤100 chars, description 20–500 chars, no body leaking into description, valid `invocation_type` and `allow_implicit` values) and scans for security threats (pipe-to-shell installers, secret exfiltration, reverse shells, obfuscated execution, prompt-injection lures). Exit 2 on critical findings; `--strict` exits 2 on any finding. CLI: `--dir <path>`, `--status`, `--strict`.
- `hooks/dispatch.sh` — deterministic orchestration substrate: a fixed state machine (intake → triage → plan → research → implement → review_gate → eval → merge_gate → done, with BLOCKED first-class) where no LLM decides what fires next. Bounded workers (including the P2 proposer/evaluator) execute steps; the substrate owns transitions and the two human-in-the-loop gates. See [`docs/handoff-schema.md`](docs/handoff-schema.md). CLI: `--intake`, `--advance`, `--block`, `--allow-gate`, `--status`, `--list`.

### Self-improvement flywheel (target architecture — P5)

P5 is the integration target: the flywheel from P0-P2 + the convergent patterns from P4, operating as a single closed loop. `hooks/cycle.sh` now exercises the whole architecture as one command, with two tracks run in sequence:

- **TRACK A — MAINTAIN** (the P4 substrate, periodic hygiene): `memory-consolidate.sh` (sleep-cycle), `skill-index.sh` (progressive-disclosure index with invocation_type + allow_implicit policy tagging), `skill-prune.sh` (telemetry-based archive candidates), `skill-validate.sh` (schema + security validation gate), `transcript-scanner.sh` (systemic pattern scan — complements `diagnose.sh`, P8.3). Advisory; stages reports, never auto-applies.
- **TRACK B — IMPROVE** (the P0-P3 flywheel, routed via `dispatch.sh`): `diagnose.sh` → `distill.sh` → `propose.sh` (at dispatch `implement` → `review_gate`) → `gate.sh` (at `eval`, with the held-out eval set the proposer never saw). On gate pass, dispatch advances to `merge_gate`; on regression, dispatch parks BLOCKED so the proposer reads WHY next time.

The cycle closes the evaluate→optimize loop through the deterministic substrate — never trusting the model to self-route or self-promote. See [`docs/target-architecture.md`](docs/target-architecture.md) for the five load-bearing subsystems and the eight load-bearing invariants. CLI: `--target <file>`, `--eval <set>`, `--dry-run`, `--status`, `--no-maintain`.

### Self-improvement flywheel (operational phase — P6)

P6 makes the flywheel actually operate in production: it schedules the cycle, seeds the trajectory for cold starts, fixes the first real finding the eval bench surfaced, and runs the first end-to-end propose → gate cycle against a live target.

- `hooks/trajectory-seed.sh` — cold-start trajectory fuel: synthesizes a small representative trajectory (mixed success/error/blocked events) so the improve track is exercisable before any real session runs. Idempotent — refuses to overwrite a non-empty trajectory; real sessions replace it. CLI: `--force`, `--status`.
- `check-pr-automation-halt.sh` (P6 fix) — now blocks `--admin` on ANY git/gh command (not just `git push`), since `--admin` bypasses branch protection regardless of subcommand. The eval bench surfaced this gap; a held-out task `pr-admin-review` locks the regression. This is the first real harness improvement driven by the bench — proof the loop works.
- `scripts/launchd/flywheel.plist.template` + `scripts/install-scheduler.sh` — opt-in macOS launchd agent that runs the cycle nightly at 02:00. Per-project (the cycle writes to `.harness/runtime/`); install once per project you want the flywheel to improve. CLI: `install [root]`, `uninstall`, `status`, `run`.
- [`docs/operations.md`](docs/operations.md) — operational runbook: cold-start → warm-start, scheduler install, reading a cycle report, interpreting the held-out lift, rollback procedure. The first real cycle (against the `--admin` fix) passed end-to-end with held-out lift=0.667.

### Self-improvement flywheel (close-the-loop — P7)

P7 closes the loop between the gate and deploy. Before P7, the gate measured the *live* hook on disk — to validate a proposal the host had to mutate the live hook, run the gate, and revert on failure (no isolation between current and proposed). P7 adds isolated candidate gating and wires deploy-watch into the cycle.

- `hooks/trial-apply.sh` — materializes a proposed edit from a proposal `.md` into a *trial copy* at `.harness/forge/trial/<proposal-id>/` (the live hook is never touched). Extracts the unified diff from the proposal's section 6, applies it via `patch`, backs up the pristine copy, emits the candidate path on stdout. Rejects a leftover `FILL IN` placeholder or a malformed diff (exit 2).
- `hooks/gate.sh` (P7) — gains `--proposal <file>`: calls `trial-apply.sh`, runs the held-out bench AGAINST THE CANDIDATE via `eval-run.sh --candidate`, records the candidate path on PASS, discards the trial dir on FAIL. The live hook is byte-identical before and after the gate run. Falls back to live-hook measurement when `--proposal` is omitted.
- `hooks/eval-run.sh` (P7) — gains `--candidate <hook-name> <path>`: the `with` variant invokes the candidate file instead of the live `$HOOKS/<hook>`. The `without` variant is unaffected. Also supports an optional task `seed` field for stateful hooks (the stuck-loop hook reads `STUCK_STATE_FILE` so the eval isolates per-task state).
- `hooks/cycle.sh` (P7) — on gate PASS, starts a `deploy-watch` with the pre-deploy held-out lift as the baseline, and the report's "what to do next" instructs the host to run `deploy-watch.sh check` after the PR merges and `revert` on REGRESSION.
- `check-stuck-loop.sh` (P7) — now reads `STUCK_STATE_FILE` (env override) so the eval harness isolates per-task state. The bench grew from 21 to 25 tasks (the fifth enforcement hook, `check-stuck-loop.sh`, now has eval coverage — 2 seen, 2 heldout).
- [`docs/operations.md`](docs/operations.md) (P7) — adds the post-merge watch flow and the close-the-loop gating section. [`docs/skill-catalog-efficiency.md`](docs/skill-catalog-efficiency.md) — competitive analysis of lean harnesses (~10-43 skills vs our 235) + a concrete reduction plan (dedup, hide sub-skills, per-agent permissions, guardrail tightening).

### Self-improvement flywheel (deep-research synthesis — P8)

P8 lands the four cherrypicks from the 52-repo deep-research survey ([`docs/harness-research-synthesis.md`](docs/harness-research-synthesis.md)) that compound the flywheel without adding runtime dependencies. Each is advisory — none blocks, none mutates memory directly.

- `hooks/reorder-context.sh` (PostToolUse) — LongContextReorder (LlamaIndex): reorders retrieved chunks so the highest-scoring land at the start/end of the window (the attention-favorable positions), since the middle is the "lost" region. Writes a digest to `.harness/runtime/reordered-chunks/`; never blocks.
- `hooks/checklist-gate.sh` (PreToolUse) — binary-checklist gates (awesome-cursorrules): a tracked checklist at `.harness/checklists/security.md` gates security-sensitive work; each item is a yes/no, not prose for the model to interpret.
- `hooks/transcript-scanner.sh` — transcript scanners (inspect-ai): complements `diagnose.sh` (the "what broke" half) with the "what the agent did that evals wouldn't flag" half — refusals (capability loss masked as success), evaluation-awareness (test-gaming), environment-drift (unremediated missing deps), hallucination signals (cited paths that failed to read), excessive-agency (force-push / `rm -rf` / `sudo` / `chmod 777` without an explicit ask), and prompt-injection tells (untrusted tool output followed as instructions). Findings stage to `.harness/forge/` for host-agent review, like `distill`. Wired into `cycle.sh` TRACK A as step 4. CLI: `--since <iso>`, `--status`.

### Self-improvement flywheel (smart approvals, reflection, TextGrad — P9)

P9 lands the three higher-value/higher-risk cherrypicks the synthesis deferred after P8. Each is advisory — none blocks, none mutates memory directly, all preserve the eight load-bearing invariants.

- `hooks/policy-gate.sh` (P9.1) — Smart Approvals prefix-rule learning (OpenAI Codex CLI): a tracked `.harness/approval-rules.json` backs learned prefix rules. A matching ALLOW rule upgrades REQUIRE_APPROVAL→ALLOW (auto-approve, logged); a matching DENY rule forces DENY (defense in depth); an ALLOW rule can never override a base DENY (the hard floor). The hook SUGGESTS rules on unmatched REQUIRE_APPROVAL; the host persists them via `--learn` (governance stays outside the model). Every auto-decision still appends to the tamper-evident ledger with `reason=auto:<prefix>`. New CLI: `--rules`, `--learn <ALLOW|DENY> <prefix> --rationale "..."`.
- `hooks/reflect-retry.sh` (P9.2) — inline retry-with-reflection (Reflexion, NeurIPS 2023): per-task reflection on a gate FAIL, distinct from the batch flywheel. Produces a structured `{what_failed, why, what_to_avoid, what_to_try_next}` digest to `.harness/forge/reflections/`; `propose.sh` injects it into section 3.5 so the next proposal retries WITH the reflection as context. Bounded by a max-retry cap (N=3 without an intervening gate PASS) — after the cap, the target is parked BLOCKED for human intervention (honors do-not-adopt #2). Fires only on eval-gated failures (honors contradiction #1). CLI: `--status`, `--count <target>`.
- `hooks/textgrad.sh` (P9.3) — TextGrad textual-gradient optimization (Nature 2025): a prescriptive gradient that complements (not replaces) the evolutionary proposer. Where the reflection is narrative (what failed and why), the gradient is PRESCRIPTIVE (which lines/sections to change and how). `propose.sh` injects it into section 3.6. Opt-in: one gradient per reflection (textgrad refuses without a reflection — no loss signal to backpropagate; honors do-not-adopt #7). CLI: `--status`.
- `hooks/propose.sh` (P9.2/P9.3) — gains sections 3.5 (latest reflection) + 3.6 (textual gradient) so the proposing model anchors on the reflection + gradient in addition to the non-Markovian history.
- `hooks/cycle.sh` (P9.2/P9.3) — on a gate FAIL (step 8), runs reflect-retry then textgrad as advisory sub-steps before the report. Step count stays 9; reflection+gradient are sub-steps of the gate-fail branch.

---

## Agents: Specialized Worker Types

~40 agent types for different tasks. Invoke via Agent tool or skills that dispatch them.

**Analysis agents** (read-only): architect, code-reviewer, critic, decision-critic, document-specialist, efficiency-advisor, explore, scientist, security-reviewer

**Execution agents** (write files): backlog-manager, ci-fixer, code-simplifier, debugger, deep-auditor, designer, git-master, handoff-writer, issue-triager, mcp-tool-dev, mutation-tester, parallel-implementer, phase-runner, pr-reviewer, rag-evaluator, refactor-orchestrator, research-decider, systematic-debugger, tdd-practitioner, team-coordinator, test-engineer, tracer, writer, xp-navigator

**Forge ecosystem**: ecosystem-coordinator, forge-patterns-expert, mcp-gateway-specialist, uiforge-mcp-architect, webapp-developer

See `~/.claude/agents/` for full definitions.

---

## Skills: 51 repo-tracked (consolidated from 103 → 50, +1 restored: sync-memories)

Skills are autonomous entry points. See `~/.claude/SKILLS.md` for the complete reference, [`docs/skill-catalog-efficiency.md`](docs/skill-catalog-efficiency.md) for the competitive analysis + reduction plan (103 → 50 via skill-family merges, stack-specific removal, and project-specific removal), and [`docs/harness-research-synthesis.md`](docs/harness-research-synthesis.md) for the 52-repo deep-research survey that informs P8.

**Consolidated catalog**: the skill catalog was reduced from 103 repo-tracked skills to 50 by merging skill families (ponytail×5→1, RAG×6→1, debug×2→1, test×6→1, session×2→1, refactor×2→1), removing stack-specific skills (shadcn, tailwind-design-system, webapp-testing), plugin-injected meta-skills, and project-specific skills. 52 skills archived in `claude/skills/.archive/` (recoverable). `sync-memories` was restored from archive as `invocation_type: internal` (was misapplied archival — it's a required `knowledge-loop` sub-skill, hidden from the always-loaded listing but resolvable by path).

**Core Development** (14): add, debug, fallback, impeccable, loop, plan, ponytail, refactor, review, scope-it, ship, tdd, test-driven-development, verify

**Architecture & Design** (7): architecture-patterns, codebase-design, decide, decide-now, domain-modeling, frontend-design, prototype

**Context & Memory** (8): codebase-memory, context-pack, context-save, graphify, handoff, knowledge-loop, memory-prune, resume

**Orchestration** (5): dispatch, loop-engineer, next-priority, orchestrate, three-man-team

**Session** (1): session-bootstrap

**Quality & Release** (8): changelog-update, ci-watch, dep-sweep, pr-merge-readiness, quality-assurance, quality-gates, setup-pre-commit, version-bump

**RAG** (2): rag-maintenance, recall

**Planning & Meta** (5): brainstorming, request-refactor-plan, secure, skill-creator-plugin, xp


The full catalog with triggers and frontmatter details is indexed by `hooks/skill-index.sh` and listed in `~/.claude/SKILLS.md`. Archived skills can be restored from `claude/skills/.archive/`.

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
1. /session-bootstrap (chains resume/priority/context-pack)
2. /plan or /scope-it for complex work
3. /dispatch or /orchestrate (≥2 independent tasks) or /loop (single task)
4. /review + /quality-gates or /verify (before merge)
5. /ship + /knowledge-loop (release, memory, handoff)
```

### Using Composites
When composite-router emits `🎯 Composite match: /<name>`: invoke that composite. Running sub-skills manually skips critical phases.

| Task | Use Composite | Why |
|------|---------------|-----|
| Refactor a module | `/request-refactor-plan` + `/orchestrate` | Preserves plan → team → validation → decision capture without restoring archived wrapper names |
| Onboard repo | `/session-bootstrap` + `/quality-assurance` | Intake, context, gates, and first safe action |
| Build feature from scratch | `/scope-it` + `/frontend-design`/`tdd`/`ship` | Research, scope, design, test, and release through active skills |
| Health check | `/quality-assurance` | Composes tests, config, security, MCP, and release evidence |
| End session | `/knowledge-loop` | Captures memory, curates weak recall, and writes handoff |

### Model Selection
- **Haiku:** Mechanical tasks (formatting, symbol lookup, grep, simple renames), subagent batch work
- **Sonnet (default):** Implementation, feature work, code review, test generation
- **Opus:** Orchestration, critic role, architectural decisions, ADR writing

Use the model-tier policy in `AGENTS.md` before multi-agent work. Never override for speculative speed.

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
| ~75% token compression | Caveman mode (default, hook-enforced) | Default behavior that drops filler/articles/pleasantries while keeping full technical accuracy. Toggle off with "stop caveman" or "normal mode". |
| Minimal solutions | `/ponytail` | Forces simplest, shortest, most minimal solution (YAGNI, stdlib before deps, one line before fifty). |
| Audit repo or diff for bloat | `/ponytail` | Built-in audit/review mode for over-engineering, ranked by evidence and size of cut. |
| Track deferred shortcuts | `ponytail:` comments | Mark deliberate shortcuts with ceiling and upgrade path in code. |
| Historical token spend | hook reports | Analyze session JSONLs, cache hit rates, and weekly trends through diagnostics. |
| Context bloat | `/context-pack` | Build focused context before large changes; compact when needed. |
| Load only relevant context | `/context-pack` | Build a task-aware context bundle before large changes or unfamiliar work. |

### Knowledge-Brain & RAG
The profile ships a **Megabrain** system: one vault for all projects (memory + graphs + RAG).

| Goal | Skill | What it does |
|------|-------|--------------|
| Semantic lookup | `/recall` | One-shot lookup against the local RAG index across memory, plans, handoffs, skills, and code. |
| Code → knowledge graph | `/graphify` | Turn code/docs/papers/images into a knowledge graph for structural queries. |
| Structural code queries | `/codebase-memory` | Knowledge graph for call chains, dead code, fan-out, impact analysis. |
| Capture and preserve knowledge | `/knowledge-loop` | Recall → capture → curate weak retrievals → handoff. |
| RAG index audit | `/rag-maintenance` | Integrated quality, coverage, drift, curation, and rebuild guidance. |

---

## Troubleshooting

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| Hooks not firing | `bat -p ~/.claude/tool-failures.log \| jq '\[\]'`; verify settings.json | Increase timeout, debug hook directly, check dependencies |
| Composite not invoked | Check session.log for `Composite match`; verify intent matches skill | Invoke directly: `/composite-name` |
| RAG retrieval stale | `/rag-maintenance` scans quality, coverage, drift, and gaps | Reindex through the maintenance workflow |
| Agent spawn failed | Verify agent exists: `fd -t f name ~/.claude/agents/` | Use default agent or check agent file syntax |
| Memory not persisting | Check sync: `bat -p ~/.claude/.sync.log` | Use `/knowledge-loop` to capture memory; verify frontmatter |
| Slow hooks / timeouts | `time bash ~/.claude/hooks/name.sh` | Increase timeout in settings.json or optimize hook |
| Parallel agents conflicting | Verify worktrees: `ls /Volumes/External\ HD/Desenvolvimento/.worktrees/` | Ensure `isolation: "worktree"` on agents |
| Token budget hit | Check `.harness/runtime/` trajectory logs or hook reports | `/compact` for relief; `/update-config` to raise limit |

---

## Getting Help

- **Skill reference:** browse `claude/skills/` or generated `~/.claude/SKILLS.md`
- **Policy questions:** check `~/.agents/skills/standards/` for decision rules
- **Hook debugging:** inspect `~/.claude/tool-failures.log`
- **Token analysis:** use diagnostics/flywheel reports for weekly spend review
- **System health:** `/quality-assurance` + `/quality-gates` for project checks
- **Stuck:** `/fallback` to recover or `/scope-it` to reframe unclear work

---

**Last updated:** 2026-06-30  
**Harness version:** Agent-OS (v8+), 52 repo-tracked skills, 40+ agents, 42 hooks, MCP policy default-deny, skill-validate errors=0
