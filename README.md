# sharekit-profile — governed agent harness for Claude Code + OpenCode

**A portable, governance-first harness profile: enforced constitution, committed threat model, MCP deny-by-default policy, and a behavioral eval gate that fails CI when agent routing regresses. Plus the full operator toolkit — 49 catalog skills (47 tracked skill folders), 55 agents, 78 lifecycle hooks, 61 standards, RAG retrieval, and memory persistence.**

This is a **profile, not a framework**: an installable, forkable, opinionated baseline you stay in control of — the home-manager for your agent config. What sets it apart from skill catalogs and agent frameworks:

- **Governance-as-code** — invariants live in `.harness/constitution.json`, enforced by hooks and CI, auditable by anyone. Agent permissions are artifacts, not vibes.
- **Behavioral eval gates** — 40 frozen routing tasks; a >5pp accuracy drop vs the fingerprinted baseline blocks the merge. Config changes are tested against measured agent behavior.
- **Security-first hooks** — gitleaks, dangerous-pattern, injection-tell, and secret-read scanners in the pre-tool-use pipeline.
- **Harness-portable** — one source of truth compiled to Claude Code and OpenCode, with drift detection between runtime copies.

> **Harnesses:** Claude Code (primary tag/discoverability surface) and OpenCode (`opencode.json`, multi-provider routing via OpenRouter fallback) are both supported natively from the same tracked source. The skill/agent/hook library is plain files — Markdown, shell, JSON — and is not locked to either harness.

---

## Install on a fresh machine

```bash
npx @lucassantana/sharekit install LucasSantana-Dev
```

What lands where: `claude/` → `~/.claude/` (47 skill folders, 55 agents, 78 hooks, 61 standards, CLAUDE.md), plus `cursor/`, `opencode/` → `~/.config/opencode/`, `gjc/` → `~/.gjc/`, and `warp/` as portable defaults.

Fresh-machine caveats:

- **Hook wiring is opt-in.** By default `settings.json` is skipped because it registers shell hooks. Re-run with `--include-hooks` to wire the hook pipeline (you get one explicit confirmation prompt). Without it, skills and agents work but nothing fires automatically.
- **External tool dependencies.** Some hooks assume tools that are not part of this profile: `rtk` (output compression), a RAG index + memory vault on an external drive, and `claude-mem`. On a machine without them the affected hooks degrade to no-ops or a one-line warning; nothing breaks, but auto-recall and token compression stay off until those exist.
- **Provider keys come from env.** `OPENCODE_API_KEY` / `OPENROUTER_API_KEY` for OpenCode, plus your normal Claude Code login. No keys ship in the profile.
- **Backups are automatic.** Every install snapshots the previous state; `sharekit rollback LucasSantana-Dev` undoes it.

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
| Full project health check | `/verify` + `/secure` | Validation gates + security-first assessment |
| Refactor a module end-to-end | `/refactor` or `/plan` + `/orchestrate` | Surgical refactoring or scoped team work |
| Ship work + capture memory | `/ship` + `/knowledge-loop` | Releases work, syncs memory, and writes handoff when needed |

### When to use composites vs. individual skills

**Always prefer composites** when the composite-router hook emits `🎯 Composite match`. Composites auto-chain phases and enforce gates. Running sub-skills manually bypasses critical phases.

Marked with `*` in skill lists below.

Example: User says "refactor this module."
- Correct: use `/refactor` + `/plan` for scope/rollback; use `/refactor` alone for surgical edits for small scope changes.
- Wrong: invoke `/refactor` directly for a broad module rewrite, skipping discovery and validation.

---

## Contributing to this repo

Local pre-commit checks (manifest fingerprint verify, harness-boundary check,
skill-validate, catalog-canonical, shellcheck, co-author-trailer scan) live in
`.husky/pre-commit` but aren't wired to git by default — clone + commit alone won't run
them, only CI will. Wire them locally once per clone:

```bash
git config core.hooksPath .husky
```

No npm/husky package needed; `.husky/pre-commit` is a plain executable script and
`core.hooksPath` is native git. Catches the same issues CI catches, before you push.

---

## Repository Structure

What you actually see when you clone this repo (for anyone submitting a PR — the
next section, "What lands where," describes the *installed* layout on an end
user's machine instead, which is a different thing):

```
sharekit-profile/
├── hooks/                    # This repo's OWN dev-time governance: .husky/pre-commit
│                             #   and .harness/manifest.json run these when YOU commit
│                             #   here. Can assume maintainer-machine tools (e.g. rg).
├── claude/                   # THE PRODUCT — installs into ~/.claude/ via
│   ├── hooks/                #   `npx sharekit install`. Must work with zero assumed
│   ├── skills/                #   deps (grep/cat, no rg) since it runs on machines
│   ├── agents/                #   this repo doesn't control.
│   ├── standards/
│   ├── settings.json          # Hook lifecycle registration for the product
│   └── CLAUDE.md               # Operator config shipped as part of the product
├── skills/                   # A second, smaller skill set (catalog-gardener,
│                             #   phase-0-audit, three-layer-eval) distinct from
│                             #   claude/skills/, added separately (#2)
├── docs/                     # Reference docs (overview, configuration, hooks,
│                             #   agents, composites, threat model)
├── tests/                    # bats test suite — `bats tests/` in CI
├── scripts/                  # Repo maintenance scripts (catalog checks, manifest
│                             #   regen, harness-boundary checks)
├── evals/                    # Behavioral routing eval gate (40 frozen tasks)
├── .harness/                 # Governance config: constitution.json, mcp-policy.json,
│                             #   manifest.json (tracked-file fingerprints)
├── .github/workflows/        # CI: harness-gates (bats + eval-gate), release-please
├── .husky/pre-commit         # Wire with `git config core.hooksPath .husky`
├── opencode/, gjc/, warp/, cursor/   # Portable default configs for other harnesses
├── specs/                    # Spec templates (docs/specs/ convention)
├── AGENTS.md                 # Governance + harness-file index (start here)
├── RULES.md                  # Hard constraints
├── SOUL.md                   # Identity/philosophy
├── CONTRIBUTING.md           # How to propose a change
└── README.md                 # This file
```

### What lands where (installed layout)

`npx sharekit install` copies `claude/` into `~/.claude/` on the *installing*
machine — this is what an end user's runtime looks like after install, not this
repo's own tree:

```
~/.claude/                    # Operator rules, hooks, state (post-install)
├── CLAUDE.md, settings.json, agents/, hooks/, skills -> ~/.agents/skills/, ...

~/.agents/                    # Canonical skill and agent definitions (post-install)
├── skills/, standards/, agents/, ...

~/.config/opencode/, ~/.gjc/  # OpenCode / Gajae-Code portable defaults (post-install)
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

- `SessionStart` — `session-start-load.sh` runs the harness drift check (live `~/.claude` vs tracked `~/.claude-env`), warns if the self-improvement flywheel has gone silent, and loads CORE memory into the session. Fails open (non-blocking warnings).
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

**Consolidated catalog**: the skill catalog was reduced from 103 repo-tracked skills to 50 (wave 1), then further pruned to 39 active (wave 2, 2026-07-01) by merging skill families, removing zero-use wrappers (ponytail, quality-gates, quality-assurance, rag-maintenance, scope-it, architecture-patterns, codebase-design, context-save, domain-modeling, request-refactor-plan, setup-pre-commit), and consolidating RAG operations. 64 skills archived in `claude/skills/.archive/` (recoverable). See `/docs/composites.md` for archived skill replacements.

**Core Development** (13): add, debug, fallback, impeccable, loop, plan, refactor, review, ship, tdd, test-driven-development, verify, xp

**Architecture & Design** (4): decide, decide-now, frontend-design, prototype

**Context & Memory** (6): codebase-memory, context-pack, graphify, handoff, knowledge-loop, memory-prune

**Orchestration** (5): dispatch, loop-engineer, next-priority, orchestrate, three-man-team

**Session** (1): session-bootstrap

**Quality & Release** (7): changelog-update, ci-watch, dep-sweep, pr-merge-readiness, version-bump, verify, xp

**RAG** (4): adt-rag, adt-rag-drift, rag-curate, recall

**Planning & Meta** (3): brainstorming, secure, skill-creator-plugin


The full catalog with triggers and frontmatter details is indexed by `hooks/skill-index.sh` and listed in `~/.claude/SKILLS.md`. Archived skills can be restored from `claude/skills/.archive/`.

---

## MCP Servers

### Local
- **rag-index** — semantic search on local knowledge base, powered by the open-source [shelfmark](https://github.com/LucasSantana-Dev/shelfmark) engine (eval methodology: [hitgate](https://github.com/LucasSantana-Dev/hitgate))
- **tavily** — web search
- **fetch** — fetch URLs
- **firecrawl** — web scraping/crawling
- **sonarqube** — code quality analysis
- **graphify** — knowledge graph queries

### Cloud (via claude.ai)
Context7, Gmail, Google Calendar, Google Drive, Hugging Face, Jam, Linear, Sentry, Vercel, Cloudflare, GitHub, Playwright, Supabase, Serena, claude-mem

> CLI-first policy (2026-07-30): local `github`, `filesystem`, and `codebase-memory-mcp` MCP servers were removed — `gh` CLI and native file tools cover those capabilities at zero per-request schema cost. See `.harness/mcp-policy.json` → `cliFirst`.

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
9. Storage on External HD (${DEV_ROOT}/)
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
2. /plan or /dispatch for complex work
3. /dispatch or /orchestrate (≥2 independent tasks) or /loop (single task)
4. /review + /quality-gates or /verify (before merge)
5. /ship + /knowledge-loop (release, memory, handoff)
```

### Using Composites
When composite-router emits `🎯 Composite match: /<name>`: invoke that composite. Running sub-skills manually skips critical phases.

| Task | Use Composite | Why |
|------|---------------|-----|
| Refactor a module | `/refactor` or `/plan` + `/orchestrate` | Preserves plan → team → validation → decision capture without restoring archived wrapper names |
| Onboard repo | `/session-bootstrap` + `/verify` + `/secure` | Intake, context, gates, and first safe action |
| Build feature from scratch | `/plan` + `/frontend-design`/`tdd`/`ship` | Research, scope, design, test, and release through active skills |
| Health check | `/verify` + `/secure` | Composes tests, config, security, MCP, and release evidence |
| End session | `/knowledge-loop` | Captures memory, curates weak recall, and writes handoff |

### Model Selection
- **Haiku:** Mechanical tasks (formatting, symbol lookup, grep, simple renames), subagent batch work
- **Sonnet (default):** Implementation, feature work, code review, test generation
- **Opus:** Orchestration, critic role, architectural decisions, ADR writing

Use the model-tier policy in `AGENTS.md` before multi-agent work. Never override for speculative speed.

### Parallel Execution
For ≥2 independent units (parallel investigations, multi-repo sweeps, batch fixes):
1. Dispatch one Agent per unit in SINGLE tool-use block
2. Use worktrees if same repo: `${DEV_ROOT}/.worktrees/<task>-<n>/`
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
| Historical token spend | hook reports | Analyze session JSONLs, cache hit rates, and weekly trends through diagnostics. |
| Context bloat | `/context-pack` | Build focused context before large changes; compact when needed. |
| Load only relevant context | `/context-pack` | Build a task-aware context bundle before large changes or unfamiliar work. |

### Knowledge-Brain & RAG
The profile ships a **Ledger** system: one vault for all projects (memory + graphs + RAG).

| Goal | Skill | What it does |
|------|-------|--------------|
| Semantic lookup | `/recall` | One-shot lookup against the local RAG index across memory, plans, handoffs, skills, and code. |
| Code → knowledge graph | `/graphify` | Turn code/docs/papers/images into a knowledge graph for structural queries. |
| Structural code queries | `/codebase-memory` | Knowledge graph for call chains, dead code, fan-out, impact analysis. |
| Capture and preserve knowledge | `/knowledge-loop` | Recall → capture → curate weak retrievals → handoff. |
| RAG index audit | `/rag-curate` | Integrated quality, coverage, drift, curation, and rebuild guidance. |

---

## Troubleshooting

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| Hooks not firing | `bat -p ~/.claude/tool-failures.log \| jq '\[\]'`; verify settings.json | Increase timeout, debug hook directly, check dependencies |
| Composite not invoked | Check session.log for `Composite match`; verify intent matches skill | Invoke directly: `/composite-name` |
| RAG retrieval stale | `/rag-curate` scans quality, coverage, drift, and gaps | Reindex through the maintenance workflow |
| Agent spawn failed | Verify agent exists: `fd -t f name ~/.claude/agents/` | Use default agent or check agent file syntax |
| Memory not persisting | Check sync: `bat -p ~/.claude/.sync.log` | Use `/knowledge-loop` to capture memory; verify frontmatter |
| Slow hooks / timeouts | `time bash ~/.claude/hooks/name.sh` | Increase timeout in settings.json or optimize hook |
| Parallel agents conflicting | Verify worktrees: `ls ${DEV_ROOT}/.worktrees/` | Ensure `isolation: "worktree"` on agents |
| Token budget hit | Check `.harness/runtime/` trajectory logs or hook reports | `/compact` for relief; `/update-config` to raise limit |

---

## Getting Help

- **Skill reference:** browse `claude/skills/` or generated `~/.claude/SKILLS.md`
- **Policy questions:** check `~/.agents/skills/standards/` for decision rules
- **Hook debugging:** inspect `~/.claude/tool-failures.log`
- **Token analysis:** use diagnostics/flywheel reports for weekly spend review
- **System health:** `/quality-assurance` + `/verify` for project checks
- **Stuck:** `/fallback` to recover or `/plan` to reframe unclear work

---

**Last updated:** 2026-06-30  
**Harness version:** Agent-OS (v8+), 52 repo-tracked skills, 40+ agents, 42 hooks, MCP policy default-deny, skill-validate errors=0
