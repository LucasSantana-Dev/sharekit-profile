# Handoff schema — deterministic orchestration substrate

This documents the **handoff packet** contract used by `hooks/dispatch.sh` and
the bounded workers it routes to. It is the coordination layer of the P4
deterministic orchestration substrate: the router owns state transitions; the
handoff packet owns what a worker receives and what it must return.

The Wave-5 multi-agent track converged on a hard rule: **no LLM decides what
fires next.** Routing and state transitions live in a deterministic substrate
(division-sh/swarm + Malphite10 + SMALL protocol + tascade). Bounded LLM
workers execute individual steps; the substrate owns the state machine so the
model cannot silently re-order, skip gates, or self-promote.

## Why a schema

Without a schema, handoffs degrade to freeform prose, which an LLM will happily
drift from: missing the blocker reason, omitting the artifact path, or claiming
done without evidence. A schema-validated packet makes the contract explicit
and machine-checkable, so the router can refuse a malformed handoff just like
`policy-gate.sh` refuses a disallowed tool.

## State machine (source of truth for transitions)

```
intake -> triage -> plan -> [research] -> implement -> review_gate
                                                    -> eval -> merge_gate
                                                    -> BLOCKED (retry/escalate)
                                                                -> done | failed
```

- `review_gate` and `merge_gate` are the two human-in-the-loop checkpoints.
  The model cannot transition past either without an explicit
  `--allow-gate <name>` from the host agent.
- `BLOCKED` is a first-class state, not a failure. It means a worker needs
  input and the router parked it rather than guessing. `--advance` refuses
  while BLOCKED; the host agent resolves the blocker, then advances or passes
  the gate.

The transition table lives in `dispatch.sh` as `declare -A NEXT`. It is the
ONLY source of truth; workers do not carry their own notion of next state.

## Dispatch packet (router -> worker)

Emitted by `dispatch.sh` to `.harness/runtime/dispatch/tasks.jsonl` as one
JSONL line per transition:

```json
{
  "ts": "2026-06-29T22:47:59Z",
  "event": "dispatch",
  "task_id": "task-001",
  "state": "research",
  "summary": "fix compaction-guard edge case",
  "worker": "bounded-worker"
}
```

- `state` is the state the task is NOW in (the router just transitioned to it).
- `worker` names who executes that state (`host`, `bounded-worker`,
  `host (gate)`, `host (unblock)`, `none` for terminal).

## Handoff packet (worker -> router)

A bounded worker returns a handoff packet when it finishes its step. The
packet tells the router the outcome and what to do next. The router does NOT
trust the worker's suggested next state unconditionally — it validates against
the transition table and gates.

```json
{
  "task_id": "task-001",
  "from_state": "research",
  "outcome": "done | blocked | failed",
  "artifact": "path/to/artifact.md",
  "evidence": "one-line summary of what was produced/verified",
  "next_hint": "implement",
  "block_reason": "required when outcome=blocked"
}
```

Fields:

- `task_id` — matches the dispatch packet.
- `from_state` — the state the worker was in.
- `outcome`:
  - `done` — step complete, advance normally.
  - `blocked` — needs input; router parks the task as `BLOCKED` with
    `block_reason`. `BLOCKED` is recoverable, not terminal.
  - `failed` — step could not complete and is not a simple blocker; router
    transitions to `failed` (terminal). Use sparingly; prefer `blocked`.
- `artifact` — the durable output of the step (a file path, branch, PR URL, or
  report path). Workers must not leave outputs only in their own context.
- `evidence` — a one-line claim the gate can check (e.g. "tests pass",
  "report staged at .harness/forge/..."). The review/merge gates verify
  evidence before allowing the transition.
- `next_hint` — the worker's suggestion; the router validates it against the
  transition table and IGNORES it if it would skip a gate.
- `block_reason` — required when `outcome=blocked`. The router records this on
  the task summary so the unblocker has context.

## Gates

### review_gate (after implement)

The host agent reviews the implementation before any eval runs. Passing
requires:

- `artifact` present (diff/PR/branch).
- `evidence` that the constraint gate (`hooks/gate.sh`) passes: tests, size,
  cache compatibility, semantic preservation, Pareto (better on >=1 axis
  without regressing others).
- A human "allow" via `dispatch.sh <task> --allow-gate review_gate`.

The model cannot self-allow. This is the evaluator-not-agent invariant from
`propose.sh`: the proposing worker is not the reviewer.

### merge_gate (after eval)

The host agent reviews the eval result before merging. Passing requires:

- `evidence` that `hooks/eval-baseline.sh` ran and the change is not a
  regression on the held-out set.
- A human "allow" via `dispatch.sh <task> --allow-gate merge_gate`.

After `merge_gate`, the task transitions to `done` (terminal).

## BLOCKED protocol

A worker signals `outcome: blocked` when it cannot proceed without input (a
missing env var, an ambiguous requirement, a dependency on another task). The
router parks the task as `BLOCKED` and records `block_reason`. The host agent
resolves the blocker and then either `--advance` (if the underlying state can
now continue) or `--allow-gate` (if the blocker was at a gate). BLOCKED is a
park, not a failure: it exists so the router never guesses what to do next
when a worker is stuck.

## Relationship to P2 proposer/evaluator

`dispatch.sh` subsumes and coordinates the P2 pair:

- `propose.sh` is a bounded worker invoked at the `implement` state (it
  assembles a non-Markovian proposal; it does not decide routing).
- `eval-baseline.sh` is a bounded worker invoked at the `eval` state (it
  measures; it does not decide to merge).
- `gate.sh` provides the evidence the gates check.

The router owns the sequence; the workers own their step. This is what makes
the substrate deterministic: remove any one worker and the state machine still
defines what comes next, so an LLM cannot re-order the pipeline.
