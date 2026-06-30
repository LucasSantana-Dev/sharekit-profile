# Target architecture — the mature self-improving harness

This describes the mature form of the `sharekit-profile` harness after the
P0-P5 roadmap: the flywheel (P0-P2) + the convergent cross-cutting patterns
(P4), operating as a single closed loop (P5). It is the integration target the
roadmap has been building toward.

The architecture exists to make one empirical claim true: **every model the
user calls returns better results than last week.** That is achieved not by
swapping models but by holding the model fixed and evolving the harness around
it — the Stanford meta-harness result.

## The five load-bearing subsystems

```
┌──────────────────────────────────────────────────────────────────────┐
│                        1. Trajectory log (observe)                   │
│   .harness/runtime/trajectory.jsonl — append-only, never pruned      │
└──────────────────────────────────────────────────────────────────────┘
        │                                  │
        ▼                                  ▼
┌─────────────────────────┐    ┌──────────────────────────────────────┐
│ 2. Deterministic        │    │ 3. External governance layer          │
│    orchestration core    │    │    (policy-gate.sh)                   │
│    (dispatch.sh)         │    │    ALLOW/DENY/REQUIRE_APPROVAL       │
│    state machine + gates │    │    tamper-evident ledger              │
└─────────────────────────┘    └──────────────────────────────────────┘
        │ owns transitions, not the LLM
        ▼
┌──────────────────────────────────────────────────────────────────────┐
│   4. Bounded LLM workers (propose, gate, distill, diagnose, eval)     │
│      bounded workers emit proposals/events; the substrate owns state │
└──────────────────────────────────────────────────────────────────────┘
        │ reads / writes
        ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 5. Temporal-KG memory backbone + progressive-disclosure skill catalog │
│    memory-consolidate.sh (bi-temporal, supersede-not-overwrite)      │
│    skill-index.sh / skill-prune.sh (metadata-only, archive-not-rm)   │
└──────────────────────────────────────────────────────────────────────┘
```

### 1. Trajectory log (observe)

`.harness/runtime/trajectory.jsonl` — the append-only, never-pruned log of
every tool call, session boundary, compaction, and incident. Written by
`trajectory-log.sh` (PostToolUse) and `session-end-flush.sh` (SessionEnd).
This is the fuel; without it, nothing improves. The non-Markovian principle
(full history retained) is the #1 lever — pruning drops performance to
best-of-N levels.

### 2. Deterministic orchestration core

`hooks/dispatch.sh` owns the state machine:
`intake -> triage -> plan -> research -> implement -> review_gate -> eval
-> merge_gate -> done`, with `BLOCKED` first-class. **No LLM decides what
fires next.** Routing and state transitions live in deterministic code; LLM
agents are bounded workers that execute individual steps and return handoff
packets. The two human-in-the-loop gates (`review_gate`, `merge_gate`) cannot
be self-allowed by the model. See `docs/handoff-schema.md`.

### 3. External governance layer

`hooks/policy-gate.sh` (PreToolUse) enforces authorization **outside the
model**: it reads `.harness/mcp-policy.json`, emits explicit
ALLOW/DENY/REQUIRE_APPROVAL verdicts, and appends each decision to a
hash-chained tamper-evident ledger bound to context hash. The model cannot
self-authorize, self-promote, or rewrite the policy. This is the deterministic
governance convergence from the Wave-5 safety/gov track.

### 4. Bounded LLM workers

The flywheel's steps are bounded workers invoked by the substrate:

- `distill.sh` — mines the trajectory for candidate learnings, stages to forge.
- `diagnose.sh` — clusters failures in the trajectory.
- `propose.sh` — assembles a non-Markovian proposal (reads WHY prior attempts
  failed). Worker at the `implement` state.
- `gate.sh` — constraint gate + held-out eval. Worker at the `eval` state.
  The held-out set is one the proposer never saw (evaluator-not-agent). `gate.sh`
  auto-runs the held-out bench via `eval-run.sh --gate-authority` before reading
  the lift, so the gate is self-sufficient: it populates its own results, never
  trusting runs the proposer authored.
- `eval-baseline.sh` — with-skill vs no-skill baseline recording + compare +
  gate. Worker at the `eval` state.
- `eval-tasks.sh` — deterministic task catalog (20 tasks split into seen /
  heldout) backing the baseline. The held-out split is enforced: `eval-run.sh`
  refuses `--split heldout` unless `--gate-authority` is passed.
- `eval-run.sh` — A/B task runner: feeds each task's synthetic tool-call event
  to its target hook in the `with` variant, simulates harness-absent in the
  `without` variant, records pass/fail + latency to `eval-baseline.sh`.

Each worker returns a handoff packet; the substrate validates the next
transition and refuses to skip a gate.

### 5. Temporal-KG memory backbone + progressive-disclosure skills

- **Memory**: the existing `claude/memory-structure/` vault, extended with
  bi-temporal validity windows (`valid_from`/`valid_to`), supersede-not-
  overwrite versioning, decay-not-delete forgetting, and a sleep-cycle
  consolidation (`memory-consolidate.sh`). See
  `claude/memory-structure/TEMPORAL_KG.md`. This is not a second memory
  system; it layers temporal invariants on the same vault.
- **Skills**: `skill-index.sh` builds a metadata-only index of the catalog
  (name + description + triggers + size class, never bodies) so the host
  loads one skill body on demand instead of load-all; `skill-prune.sh` reads
  the trajectory and stages never-hit / low-hit skills as archive candidates.
  Pruning = archive, never `rm`.

## The closed loop (P5)

`hooks/cycle.sh` exercises the whole architecture as one command. It runs two
tracks in sequence:

- **TRACK A — MAINTAIN** (the P4 substrate, periodic hygiene):
  1. `memory-consolidate.sh` — sleep-cycle: cluster/supersede/decay candidates.
  2. `skill-index.sh` — metadata-only catalog index.
  3. `skill-prune.sh` — never/low-hit archive candidates.
- **TRACK B — IMPROVE** (the P0-P3 flywheel, routed via dispatch.sh):
  4. `diagnose.sh` — cluster failures in the trajectory.
  5. `distill.sh` — mine trajectory → staged candidates.
  6. `propose.sh` (at `implement`) → dispatch advances to `review_gate`.
  7. `gate.sh` (at `eval`, after `--allow-gate review_gate`) → on pass,
     dispatch advances to `merge_gate`; on regression, dispatch parks BLOCKED.
  8. Report — the cycle summary the host agent reviews.

The cycle NEVER commits (hermes-evolution guardrail #5). It produces a report;
the host agent reviews, passes `merge_gate` via `dispatch.sh --allow-gate
merge_gate`, and opens a human-reviewed PR. `deploy-watch.sh` runs post-merge
and auto-reverts on regression, recording the failure in history so the
proposer reads WHY next time.

## The load-bearing invariants

These are the non-negotiable properties that make the architecture work. They
are enforced by hooks, the review gate, and the substrate — not by trusting
the model.

1. **Evaluator ≠ agent.** The judge never ships in the harness; the reviewer is
   not the proposer (lumos, gearbox, auto-harness).
2. **Non-Markovian full history.** Every iteration's code, score, and trace is
   preserved; the proposer reads WHY prior attempts failed, not just that they
   failed. `history.sh` NEVER prunes.
3. **All edits human-reviewed via PR.** Never direct commit. Graduation
   requires a rationale (no rubber-stamping).
4. **Auto-rollback on regression.** `deploy-watch.sh` reverts to git HEAD on
   post-deploy regression and records it in history.
5. **Deterministic routing.** `dispatch.sh` owns state transitions, not the
   LLM. The model cannot re-order the pipeline or skip a gate.
6. **Governance outside the model.** `policy-gate.sh` emits ALLOW/DENY
   verdicts from a declarative policy the model cannot rewrite, with a
   tamper-evident ledger.
7. **Supersede-not-overwrite / decay-not-delete.** Memory history is never
   lost; facts are superseded via links and archived, never overwritten or rm'd.
8. **Progressive disclosure.** Skill bodies load on demand from a
   metadata-only index; load-all causes context rot.

## Why this transfers across any model

The improvement is in the **harness**, not the weights: prompts, tool
descriptions, hooks, stop conditions, memory, control flow. Because the
evolved harness is model-agnostic, a better hook fires for Claude, Codex,
OpenCode, and Warp alike. The meta-harness result that a frozen evolved harness
transfers without re-evolution to alternate base models is the empirical proof.

## Do-not-adopt-as-dependencies

The loop **shape** is adopted; the heavy runtimes are not:
- `contextweaver`, `doneyli` template, `LangfuseMCP` (reference only).
- `hermes-agent-self-evolution`, `polyharness`, `harness-evolver` runtimes
  (LangSmith/DSPy/GEPA) — reference the loop contract, do not install.

The harness stays local, zero-dep, file-first. Wire a local proposer only once
telemetry + the eval gate exist (they do, as of P0-P2).
