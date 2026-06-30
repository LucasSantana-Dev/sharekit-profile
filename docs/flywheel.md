# The self-improvement flywheel

> How the harness improves with use across any model.
> Implements the Wave-4 research findings (meta-harness, auto-harness, meta-agent,
> selftune, harness-evolver, gearbox, lumos, agentic-stack, forge, AHE).

## The thesis

**Harness design is the #1 performance lever — more than model choice.**
Stanford's Meta-Harness (IRIS Lab, 2026) showed that holding the model fixed and
evolving only the harness systematically beats best-of-N sampling and model
hopping. The same Claude Sonnet scores 20+ points differently on SWE-bench
depending on the harness wrapping it. So the path to "optimal results on any
model I call" is **not** to keep swapping models — it is to make the harness
self-improve.

Knowledge persistence (saving notes about what worked) is **not** a closed loop.
There is no measurement, no validation, and no rollback. The flywheel below is
the closed loop.

## The loop

```
Session runs (any harness: OpenCode / Claude Code / Codex / Warp)
  ↓ SessionStart        — load CORE memory + drift check (hooks/session-start-load.sh)
  ↓ PreToolUse          — enforce invariants + log trajectory (check-*.sh)
  ↓ PostToolUse         — append tool-call event to trajectory (trajectory-log.sh)
  ↓ PreCompact          — snapshot pre-compaction state (snapshot-compact.sh)
  ↓ PostCompact         — re-inject CORE memory (reinject-compact.sh)
SessionEnd
  ↓ flush trajectory + write session record + queue for distill (session-end-flush.sh)
  ↓ Stop                — post-incident ADR reminder if errors spiked (post-incident-adr.sh)
Nightly distill (auto_dream)
  ↓ cluster + heuristic prefilter + decay
  ↓ stage candidate learnings (confidence-scored)
  ↓ host-agent review: graduate (--rationale required) / reject / reopen
  ↓ promote to semantic memory / CORE / skills
Periodic eval gate (P1)
  ↓ with-skill vs no-skill baseline
  ↓ propose skill/prompt/hook edits with predicted impact
  ↓ constraint gate + held-out split + Pareto selection
  ↓ auto-rollback on regression; human-reviewed PR merges the winner
Result: every model called returns better results than last week
```

## The three phases

### Observe (P0 — shipped in this wave)

Hooks emit structured events to an append-only log
(`.harness/runtime/trajectory.jsonl`). Every tool call, every session boundary,
every compaction, every incident is recorded. This is the fuel; without it,
nothing improves.

- `trajectory-log.sh` (PostToolUse) — one JSONL event per tool call with outcome
  (success/error/blocked), truncated input + response.
- `session-end-flush.sh` (SessionEnd) — session record (tool-call counts, error
  counts, top tools) + boundary marker + queue for distill.
- `snapshot-compact.sh` (PreCompact) — pre-compaction state recovery.
- `reinject-compact.sh` (PostCompact) — CORE memory survives compaction.
- `session-start-load.sh` (SessionStart) — CORE load + drift check.

### Evaluate (P1 — shipped in this wave)

The distill mines the trajectory for candidate learnings; the eval gate
measures whether a skill/prompt/hook actually helps; the self-diagnosis clusters
failures; the context-guard defends the context window.

- **Nightly distill** — `hooks/distill.sh` clusters + prefilters + confidence-
  scores candidates (decisions/learnings/failures/patterns). Stages to
  `.harness/forge/`; **never** mutates semantic memory directly. See
  `claude/memory-structure/SELF_IMPROVEMENT.md`.
- **Host-agent review** — `hooks/review.sh` graduate/reject/reopen CLI.
  Graduation requires `--rationale`; no rubber-stamping. Mirrors
  agentic-stack `graduate.py`/`reject.py`/`reopen.py`.
- **with-skill vs no-skill baseline** — `hooks/eval-baseline.sh` records A/B
  runs and gates on measurable lift (selftune `baseline` pattern). Local,
  zero-dep. Backed by a real task catalog (`hooks/eval-tasks.sh`, 20 deterministic
  harness-behavior tasks across the enforcement hooks) and an A/B runner
  (`hooks/eval-run.sh`) that feeds each task's synthetic tool-call event to its
  target hook and checks the exit code matches the expected verdict. The catalog
  is split into **seen** (proposer may inspect) and **heldout** (gate-only); the
  held-out split is enforced — `eval-run.sh` refuses `--split heldout` unless
  passed `--gate-authority`, which only `gate.sh` supplies (evaluator-not-agent
  invariant). `gate.sh` auto-runs the held-out bench before reading the lift, so
  the gate is self-sufficient: it populates its own results, never trusting runs
  the proposer authored.
- **self-diagnosis** — `hooks/diagnose.sh` clusters failures in the trajectory
  log, surfaces root-cause candidates, detects repeated errors / tool overuse /
  blind retries / token-waste patterns (SkillForge + AHE Agent Debugger).
- **context defense** — `hooks/context-guard.sh` PostToolUse hook: tool-result
  firewall (compact digest sidecars for >2KB responses), lost-in-the-middle
  audit (constraint recap surfaced at window start), cache-boundary marker
  (contextweaver 92.2% route-prompt reduction, agentforge).
- **two-knob observability** — `hooks/observe-otel.sh` global default +
  per-project override (pdhoolia); GenAI semantic span names; context-breach
  scanning; idempotent ±1 feedback scores. Local JSONL by default; wire an
  OTEL exporter via `OTEL_EXPORTER_OTLP_ENDPOINT` when ready.
- **evaluator ≠ agent** — the judge never ships in the harness; the reviewer is
  not the implementer (lumos, gearbox, auto-harness).

### Optimize (P2 — shipped in this wave)

The optimize half closes the loop: a proposer reads the full non-Markovian
iteration history, proposes evidence-backed edits, is gated, deployed, watched,
and auto-reverted on regression. The contract is copied from meta-agent /
harness-evolver / hermes-evolution — NOT a dependency. No DSPy/GEPA/LangSmith.

- **iteration history** — `hooks/history.sh` is the #1 lever. Append-only JSONL
  of every proposal + its eval result + WHY it failed/regressed. NEVER prunes —
  the meta-harness result is that pruning history to recent-only drops
  performance to best-of-N levels. `why <target>` surfaces the failure reasons.
- **evolutionary proposer** — `hooks/propose.sh` assembles a non-Markovian
  proposal context: iteration history (the why) + latest diagnosis + staged
  distill candidates + current file content + a constraint-gate checklist. The
  proposing model fills in the edit + predicted impact. NEVER commits directly.
- **constraint gate** — `hooks/gate.sh` validates before review: tests pass,
  skill size ≤15KB, cache compatibility (no mid-conversation change), semantic
  preservation (held-out eval lift ≥ 0), Pareto selection. The gate reads the
  held-out eval results the proposer did NOT author (meta-agent pattern).
- **auto-rollback + deploy-watch** — `hooks/deploy-watch.sh` monitors post-deploy
  metrics; auto-backs-up before any revert; reverts to git HEAD on regression;
  records the regression in history so the proposer learns from it next time.
- **repo map** — `hooks/repo-map.sh` produces a bounded, cache-stable structural
  map (file tree + symbol index, ≤8KB budget) so the proposer targets edits
  correctly without flooding context (lost-in-the-middle defense).
- **all edits human-reviewed via PR** — evolved variants never commit directly
  (hermes-evolution guardrail #5). The proposer proposes; the gate validates; the
  host agent reviews and opens the PR.

### Exercise the loop (P3 — shipped in this wave)

The P0/P1/P2 scripts defined the loop contract; P3 makes it exercisable as a
single command and ships the last two context-engineering defenses. The P3
follow-up ships the concrete eval bench (task catalog + held-out split + A/B
runner) that turns the eval gate from a recording mechanism into a real
measurement.

- **end-to-end cycle runner** — `hooks/cycle.sh` chains the full loop in one
  command: diagnose → distill → propose → gate → report. It skips steps
  gracefully from a cold start (empty trajectory, no candidates) and NEVER
  commits — it produces a cycle report the host agent reviews. This is the
  command that makes the flywheel runnable on demand (or on a schedule):
  `hooks/cycle.sh` for a full step, `--dry-run` to preview, `--status` to
  re-read the last report, `--target <file>` to anchor the proposal.
- **bounded tool shortlist** — `hooks/tool-shortlist.sh` (UserPromptSubmit):
  surfaces only the tools whose keywords match the prompt instead of the full
  catalog, cutting system-prompt context (contextweaver 92.2% route-prompt
  reduction, agentforge deferred-tools 60-70% system-prompt cut). Advisory;
  never blocks.
- **cache-aware model routing** — `hooks/model-cache-guard.sh` (UserPromptSubmit
  + PostCompact): flags mid-conversation model switches as cache-unsafe, since
  switching mid-stream discards the cached prompt prefix. The only cache-safe
  switch boundaries are first-turn and post-compaction (Copilot pattern).
  Advisory; never blocks.

- **eval task catalog** — `hooks/eval-tasks.sh`: a deterministic catalog of 20
  harness-behavior tasks (each = synthetic tool-call event + expected verdict +
  owning hook) split into **seen** (proposer trains on) and **heldout** (gate
  evaluates on; proposer never sees the per-task expected verdicts). The split
  is the overfitting defense: a harness edit that hard-codes the seen cases
  fails on held-out (meta-agent / harness-evolver pattern). CLI: `list
  [--split seen|heldout|all]`, `show <id>`, `count [--split ...]`.
- **A/B task runner** — `hooks/eval-run.sh`: runs each task in with/without
  variants and records to `eval-baseline.sh`. `with` invokes the target hook on
  the task input and checks the exit code matches the expected verdict;
  `without` simulates the harness absent (always allow). Enforces the held-out
  split: refuses `--split heldout` unless `--gate-authority` is passed, which
  only `gate.sh` supplies. CLI: `--eval <name> --variant with|without
  [--split seen|heldout|all] [--gate-authority]`.

### Convergent cross-cutting patterns (P4 — shipped in this wave)

The P0-P3 scripts defined the loop and made it exercisable; P4 layers the five
convergent cross-cutting patterns the Wave-5 research tracks agreed on. These
are the defenses that keep the loop honest as it scales: context control,
governance, temporal memory, progressive disclosure, and deterministic
orchestration. Each is advisory-or-gated, never trust-the-model.

- **hybrid context control** — `hooks/compaction-guard.sh` (PreCompact):
  audits tool-call/result adjacency preservation during compaction so execution
drift cannot hide in a condensed window, emits threshold-triggered budget
warnings (~70% redis pattern), and advises cache-prefix stability. Advisory;
never blocks (championswimmer/pi-context-prune, OpenHands condenser, agentcache).
- **deterministic governance layer** — `hooks/policy-gate.sh` (PreToolUse):
  emits explicit ALLOW/DENY/REQUIRE_APPROVAL verdicts from `mcp-policy.json`
outside the model, appends each decision to a hash-chained tamper-evident
ledger bound to context hash, and exits 2 on DENY. Includes `--verify` ledger
integrity and `--status` verdict counts (microsoft/agent-governance-toolkit,
cordum, provenex, agence Merkle chain).
- **temporal-KG consolidation** — `hooks/memory-consolidate.sh`: a sleep-cycle
  scan that clusters related facts, finds supersede candidates, finds
compression clusters, and decays stale+low-confidence facts — all staged to
`.harness/forge/` and never auto-applied. Extends the existing promotion ladder
with bi-temporal validity windows (supersede-not-overwrite, decay-not-delete).
See `claude/memory-structure/TEMPORAL_KG.md` (graphiti, agmem, hdviettt,
apattichis).
- **progressive-disclosure skills** — `hooks/skill-index.sh` builds a
  metadata-only index of the skill catalog (name + description + triggers +
size class, never bodies) so the host loads one skill body on demand instead of
load-all; `hooks/skill-prune.sh` reads the trajectory and stages never-hit /
low-hit skills as archive candidates. Archive, never `rm` (microsoft 4-tier,
openai/codex metadata-only preload, TAKEOFF69 retrospective).
- **deterministic orchestration** — `hooks/dispatch.sh` is the routing
  substrate: a fixed state machine (intake -> triage -> plan -> research ->
implement -> review_gate -> eval -> merge_gate -> done, with BLOCKED
first-class) where NO LLM decides what fires next. Bounded workers (including
the P2 proposer/evaluator) execute steps; the substrate owns transitions and
the two human-in-the-loop gates. See `docs/handoff-schema.md` (division-sh/swarm,
Malphite10, SMALL protocol, tascade).

### Operational phase (P6 — shipped in this wave)

P6 makes the flywheel actually operate in production: it schedules the cycle,
seeds the trajectory for cold starts, fixes the first real finding the eval
bench surfaced, and runs the first end-to-end propose → gate cycle against a
live target. This is the phase where the loop stops being a contract and
starts improving the harness.

- **trajectory seed** — `hooks/trajectory-seed.sh`: synthesizes a small
  representative trajectory (mixed success/error/blocked tool-call events) so
  the improve track has fuel from a cold start. Idempotent — refuses to
  overwrite a non-empty trajectory; real sessions replace it. CLI: `--force`,
  `--status`.
- **first real fix driven by the bench** — `check-pr-automation-halt.sh` now
  blocks `--admin` on ANY git/gh command (not just `git push`), since
  `--admin` bypasses branch protection regardless of subcommand. The eval
  bench surfaced this gap (`gh pr merge --admin` slipped through); a held-out
  task `pr-admin-review` locks the regression. The held-out lift rose from
  0.545 to 0.667.
- **first real cycle** — ran `cycle.sh --target hooks/check-pr-automation-halt.sh
  --eval harness` end-to-end: maintain track (memory-consolidate, skill-index,
  skill-prune) + improve track (diagnose, distill, propose, gate) all passed.
  Gate held-out lift=0.667 (with=12/12, without=4/12). Every load-bearing
  subsystem fired in sequence against a real edit.
- **nightly scheduler** — `scripts/launchd/flywheel.plist.template` +
  `scripts/install-scheduler.sh`: opt-in macOS launchd agent that runs the
  cycle nightly at 02:00. Per-project (the cycle writes to `.harness/runtime/`);
  install once per project you want the flywheel to improve. CLI: `install
  [root]`, `uninstall`, `status`, `run`.
- **operational runbook** — `docs/operations.md`: cold-start → warm-start,
  scheduler install, reading a cycle report, interpreting the held-out lift,
  rollback procedure.

### Close-the-loop (P7 — shipped in this wave)

P6 ran the first real cycle, but the gate measured the *live* hook on disk — to
validate a proposal the host had to mutate the live hook, run the gate, and
revert on failure. P7 closes that gap: the gate now validates a PROPOSED edit
in isolation, and deploy-watch is wired into the cycle so a post-merge
regression is detectable. The loop is now genuinely closed.

- **isolated candidate gating** — `hooks/trial-apply.sh` materializes the
  proposed diff from a proposal `.md` into a *trial copy* at
  `.harness/forge/trial/<proposal-id>/` (the live hook is never touched). It
  rejects a leftover `FILL IN` placeholder or a malformed diff. `hooks/gate.sh
  --proposal <file>` runs the held-out bench against the trial copy via
  `eval-run.sh --candidate <hook> <path>`. On PASS the candidate path is
  recorded; on FAIL the trial dir is discarded. The live hook is byte-identical
  before and after the gate run.
- **candidate-aware eval runner** — `hooks/eval-run.sh --candidate <hook> <path>`
  invokes the candidate file instead of the live `$HOOKS/<hook>` for the `with`
  variant. The `without` variant is unaffected. This is what makes isolated
  gating possible without a schema change.
- **stateful-hook eval isolation** — `check-stuck-loop.sh` now reads
  `STUCK_STATE_FILE` (env override) so the eval harness can isolate per-task
  state via a temp file. The bench seeds N identical-hash entries (the task's
  `seed` field) so the live call presents as the (N+1)th attempt.
- **stuck-loop eval coverage** — `eval-tasks.sh` grew from 21 to 25 tasks (2
  seen, 2 heldout) for the Stuck-protocol hook, the fifth enforcement hook.
  Before P7 it had zero coverage; a regression there was invisible to the gate.
- **deploy-watch wired into the cycle** — on a gate PASS, `cycle.sh` calls
  `deploy-watch.sh start <pid> <target> heldout-lift <pre-deploy-lift>`, so a
  post-merge regression is detectable. The cycle report's "what to do next"
  now instructs the host to run `deploy-watch.sh check` after the PR merges and
  `revert` on REGRESSION.
- **proof** — ran `gate.sh --proposal` end-to-end against a real edit to
  `check-stuck-loop.sh` (threshold 3 -> 2). The gate materialized the
  candidate, ran the held-out bench AGAINST THE CANDIDATE (lift=0.654), and
  the live hook stayed byte-identical pre/post (same sha256). A deliberately
  broken candidate failed the gate, the trial dir was discarded, and the live
  hook was still untouched.

### Deep-research synthesis -> P8 (shipped in this wave)

A 52-repo survey (see `docs/harness-research-synthesis.md`) named the next
10 cherrypicks; P8 lands the four that compound the flywheel without adding
runtime dependencies or trusting the model to self-police. Each is advisory —
none blocks, none mutates memory directly.

- **LongContextReorder (P8.1)** — `hooks/reorder-context.sh` (PostToolUse):
  reorders retrieved chunks so the highest-scoring land at the start and end
  of the window (the attention-favorable positions), the LlamaIndex
  LongContextReorder finding that the middle is the "lost" region. Advisory;
  writes a digest to `.harness/runtime/reordered-chunks/`, never blocks.
- **Binary-checklist gates (P8.2)** — `hooks/checklist-gate.sh` (PreToolUse):
  the awesome-cursorrules binary-checklist pattern made concrete. A tracked
  checklist at `.harness/checklists/security.md` gates security-sensitive
  work; each item is a yes/no, not prose for the model to interpret.
- **Transcript scanners (P8.3)** — `hooks/transcript-scanner.sh`: complements
  `diagnose.sh` (the "what broke" half) with the inspect-ai "scanners" half
  (the "what the agent did that evals wouldn't flag" signals): refusals
  (capability loss masked as success), evaluation-awareness (test-gaming),
  environment-drift (unremediated missing deps), hallucination signals (cited
  paths that failed to read), excessive-agency (force-push / `rm -rf` /
  `sudo` / `chmod 777` without an explicit ask), and prompt-injection tells
  (untrusted tool output followed as instructions). Findings stage to
  `.harness/forge/` for host-agent review, like `distill`. Wired into
  `cycle.sh` TRACK A as step 4 (maintain/hygiene), so the loop scans for
  systemic patterns every cycle, not just failure clusters.

### The target architecture (P5 — shipped in this wave)

P5 is the integration target: the flywheel from P0-P2 + the convergent patterns
from P4, operating as a single closed loop. `hooks/cycle.sh` now exercises the
whole architecture as one command, with two tracks:

- **TRACK A — MAINTAIN**: `memory-consolidate.sh` (sleep-cycle), `skill-index.sh`
  (progressive disclosure), `skill-prune.sh` (telemetry-based archive candidates),
  `transcript-scanner.sh` (systemic pattern scan — complements `diagnose.sh`).
- **TRACK B — IMPROVE**: `diagnose.sh` -> `distill.sh` -> `propose.sh` (routed at
  dispatch `implement` -> `review_gate`) -> `gate.sh` (routed at `eval`, with the
  held-out eval set the proposer never saw) -> on pass, dispatch advances to
  `merge_gate`; on regression, dispatch parks BLOCKED. The cycle closes the
evaluate->optimize loop through the deterministic substrate, never trusting the
model to self-route or self-promote. See `docs/target-architecture.md` for the
five load-bearing subsystems and the eight load-bearing invariants.

## Why this works across any model

The model is held fixed; what evolves is the **harness around it** — prompts,
tool descriptions, hooks, stop conditions, memory, control flow. Because the
improvement is in the harness, not the weights, it **transfers** to any model
the user calls: a better hook fires for Claude, Codex, OpenCode, and Warp alike.
The meta-harness result that a frozen evolved harness transfers without
re-evolution to alternate base models is the empirical proof.

## Non-Markovian search — keep the history

Every iteration's code, score, and trace is preserved. The proposer reads prior
candidates and traces before writing the next one. This is why the trajectory
log is append-only and gitignored (it is runtime fuel, not source of truth) —
but the *graduated learnings* and *evolved harness files* are committed, so the
improvement is durable and diffable.

## Sequencing (what depends on what)

```
settings.json (enforcement)  ── must precede ──▶  trajectory log (observe)
                                                       │
trajectory log (observe)     ── must precede ──▶  eval baseline (evaluate)
                                                       │
eval baseline (evaluate)     ── must precede ──▶  proposer (optimize)
                                                       │
proposer + eval gate         ── must precede ──▶  auto-rollback + PR merge
```

A proposer without telemetry + held-out eval is just guesswork — the explicit
lesson from selftune vs "agents that save notes." That is why this wave ships
**observe** (P0) and documents **evaluate/optimize** (P1/P2) as the next gates.

## Do-not-adopt-as-dependencies

The loop **shape** is adopted; the heavy runtimes are not:
- `contextweaver` (Weaver Stack), `doneyli` template (Docker), `LangfuseMCP`
  (reference only).
- `hermes-agent-self-evolution`, `polyharness`, `harness-evolver` runtimes
  (LangSmith/DSPy/GEPA) — reference the loop contract, do not install. Wire a
  local proposer only once telemetry + the eval gate exist.

### Smart Approvals, reflection, TextGrad (P9 — shipped in this wave)

P9 lands the three higher-value/higher-risk cherrypicks the synthesis deferred
after P8: Smart Approvals prefix-rule learning, inline retry-with-reflection
(Reflexion), and TextGrad textual-gradient optimization. Each is advisory — none
blocks, none mutates memory directly, all preserve the eight load-bearing
invariants.

- **Smart Approvals (P9.1)** — `hooks/policy-gate.sh` gains prefix-rule
  learning backed by a tracked `.harness/approval-rules.json`. A matching ALLOW
  rule upgrades REQUIRE_APPROVAL->ALLOW (auto-approve, logged); a matching DENY
  rule forces DENY (defense in depth); an ALLOW rule can never override a base
  DENY (the hard floor). The hook SUGGESTS rules on unmatched REQUIRE_APPROVAL;
  the host persists them via `--learn` (governance stays outside the model).
  Every auto-decision still appends to the tamper-evident ledger with
  `reason=auto:<prefix>`. CLI: `--rules`, `--learn <ALLOW|DENY> <prefix>
  --rationale "..."`.
- **Inline retry-with-reflection (P9.2, Reflexion)** — `hooks/reflect-retry.sh`:
  per-task reflection on a gate FAIL, distinct from the batch flywheel. Produces
  a structured `{what_failed, why, what_to_avoid, what_to_try_next}` digest to
  `.harness/forge/reflections/`; `propose.sh` injects it into section 3.5 so the
  next proposal retries WITH the reflection as context. Bounded by a max-retry
  cap (N=3 without an intervening gate PASS) — after the cap, the target is
  parked BLOCKED for human intervention (the Reflexion bound; honors do-not-adopt
  #2). Fires only on eval-gated failures (honors contradiction #1).
- **TextGrad textual-gradient (P9.3)** — `hooks/textgrad.sh`: a TextGrad-style
  optimization pass that complements (not replaces) the evolutionary proposer.
  Where the reflection is narrative (what failed and why), the gradient is
  PRESCRIPTIVE (which lines/sections to change and how). `propose.sh` injects it
  into section 3.6 so the proposing model anchors on the gradient in addition
  to the non-Markovian history + reflection. Opt-in: one gradient per reflection
  (textgrad refuses without a reflection — no loss signal to backpropagate).
  Honors do-not-adopt #7 (textgrad is NOT the sole optimizer — it is one of an
  ensemble).
- **cycle.sh wiring** — on a gate FAIL (step 8), the cycle runs reflect-retry
  then textgrad as advisory sub-steps before the report (step 9). The step count
  stays 9; reflection+gradient are sub-steps of the gate-fail branch, not new
  top-level steps. The cycle report's gate-fail note now records the reflection
  retry count.

*Last updated: 2026-06-30 (P9 shipped — Smart Approvals, inline reflection, TextGrad)*
