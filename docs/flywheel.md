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
  zero-dep.
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

*Last updated: 2026-06-29*
