---
name: resolve-before-asking
description: Answer a would-be clarifying question yourself instead of stopping, when it's researchable, reversible, and not T3 — run deep-research then debate then grill-with-docs, commit to the best option, and park residual doubt in the handoff. Use when about to reach for AskUserQuestion on an ambiguous requirement, scope, or preference under full autonomy. Never for destructive, irreversible, production, money, or other-author-PR actions — always ask, no bypass.
triggers:
  - resolve before asking
  - don't ask me, just decide
  - full autonomy, figure it out
  - research it instead of asking
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: /Users/lucassantana/.agents/skills/resolve-before-asking
---

# Resolve Before Asking

Substitutes a research pass for a clarifying question, but only for questions research
can actually settle. It is not a way to avoid ever asking — it is a way to stop asking
questions that evidence, not the operator's presence, would answer.

## Use When

- About to call `AskUserQuestion` on a judgment call that is genuinely blocking, but an
  evidence-backed answer likely exists (in code, docs, prior decisions, or external
  sources) and getting it wrong costs less than a session to undo.
- A full-autonomy directive ("don't ask me, decide") is active and a scope/design/approach
  question surfaces mid-task that would otherwise stop the turn.

## Do Not Use When

| Situation | Use instead |
|---|---|
| Already deliberated 3+ turns with no new evidence, going in circles | `decide-now` |
| A named tech/library/architecture adoption choice that should end in a durable record | `research-and-decide` / `decide` |
| Challenging a plan against domain docs as a standalone step (not part of resolving a blocked question) | `grill-with-docs` directly |
| Repeating the same action/fix without progress | `loop` |
| A preferred tool/path failed | `fallback` |
| Pure taste/bikeshed with no research surface (naming, tabs vs spaces) | Pick a sensible default silently, no skill needed |
| Only the operator has the answer (priorities, budget, "do you even want this") | Ask directly via `AskUserQuestion` |
| T3 action: destructive, irreversible, production/deploy/migration, money, other-author PR/outward publish | `AskUserQuestion` — always, no bypass, this skill refuses |

## Workflow

### 0. Gate — all three required, checked in this order

1. **Not T3.** Cross-check the literal trip list from `standards/autonomy-tiers.md`
   (ADR-0051): destructive op, irreversible op, production/deploy/migration, money,
   other-author PR/outward publish. Match on any → **stop here**, ask via
   `AskUserQuestion`, no bypass. Do not proceed into Phase 1 even if you're confident
   research would settle it — the gate is about authorization, not correctness.
2. **Researchable.** An evidence-backed answer exists outside the operator's own head.
   Pure preference/taste/priority fails this test → ask directly or pick a silent
   reasonable default; do not invoke the pipeline below.
3. **Reversible.** Cost of a wrong answer is bounded and undoable within roughly the
   current session (T0-T2). If the honest undo cost is a full session or more of rework,
   treat it as T3-adjacent and ask.

All three pass → continue. Any fails → resolve per that gate's instruction; this skill's
job ends there.

### 1. Deep-research — gather evidence

Invoke `deep-research` on the exact question. Internal-only questions (harness/skill
conventions, this repo's own policy) auto-route INTERNAL mode; external tech questions
route EXTERNAL/HYBRID.

### 2. Debate — commit to a synthesis

Invoke `debate` with the research output as the ARTIFACT (minimum 3 genuinely distinct
lenses for the question). Debate's synthesis is the plan this skill commits to — a
synthesis that silently averages instead of naming a winner does not count; re-run or
escalate per debate's own failure conditions.

### 3. Grill-with-docs — challenge against existing docs (conditional)

If the question touches domain terminology, `CONTEXT.md`, or an existing ADR: invoke
`grill-with-docs` against debate's synthesis, self-answering each challenge round (no
human is present in full-autonomy mode — do not pause waiting for one). If no doc surface
is relevant to a purely mechanical/internal question, skip this phase and say so
explicitly in your output. Never fabricate a self-answer against nothing.

**Context checkpoint — before Phase 2 and before Phase 3:** if remaining context is under
~25%, invoke `handoff` directly (not `knowledge-loop` — its Phase 4 snapshot self-skips
when "work continues," which is exactly this state), compact, then resume at the phase
you stopped at.

### 4. Commit, or park the residual doubt

- **Converged:** state the committed option plainly in your next output and proceed. Do
  not keep researching once debate (and grill, if run) named a winner.
- **Still doubtful after all three phases:** proceed on the best-supported option anyway
  — never leave the turn blocked on a question this skill exists to avoid asking. Append
  a `## Parked Questions` section to the active handoff file (create one via `handoff` if
  none exists yet) with: the question, the option chosen and why, the evidence for it,
  and the reversal cost. This is the resurfacing mechanism — `wake-up`/session-bootstrap
  already reads the latest handoff at next session start, so nothing further is needed to
  make it reappear.
- **Repo mandates issue capture** (e.g. this repo's CLAUDE.md §5, "Map Every Finding to a
  GitHub Issue"): also file a `needs-info`-labeled issue for the parked question, deduped
  against open issues first. This is an addendum, not a substitute for the handoff entry.

## Outputs / Evidence

- Gate result: which of the 3 conditions, pass/fail, and why.
- Research summary, debate synthesis, grill verdict (or explicit skip reason).
- Final line: `committed: <option> — <why>` or `parked: <handoff path> § Parked Questions`.

## Failure / Stop Conditions

- T3 gate trips at any point — including mid-research, if new evidence reveals the action
  is actually destructive/irreversible — stop immediately, ask, no bypass.
- Research/debate/grill find no evidence either way on a non-trivial question: still
  commit to the best-supported option per the default "proceed and report" posture; do
  not leave the task blocked mid-turn.
- Do not grind the "reversible" gate down until it technically passes just to avoid
  asking — if undo genuinely costs a session or more, that fails the gate; ask.

## Memory Hooks

- Memory read happens inside `deep-research`'s INTERNAL-mode pass — do not duplicate a
  separate `recall` here.
- This skill does not write memory directly; the parked-question sink is the handoff
  file. If a resolved question turns into a durable convention, that's `sync-memories`'s
  or `adr-write`'s job downstream, not this skill's.
