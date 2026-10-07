---
name: spec-driven-develop
description: "Default entry for non-trivial build/add/fix/refactor: specify, plan, tasks, implement, verify. Not if a narrower composite (hotfix etc) fits; skip <3 files."
user-invocable: true
auto-invoke: build X, add X, implement X, fix X, refactor X, ship this feature, non-trivial change with no more specific composite matching
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/spec-driven-develop
---

# Spec-Driven Develop

Composite skill. Chains existing skills into spec-kit's phase order and terminology, without spec-kit's CLI or `.specify/` directory convention.

## When this fires

- The user asks to build, add, implement, fix or refactor anything non-trivial (≥3 files, or any ambiguity about what "done" means) and no more specific lifecycle composite matches.
- The `composite-router` hook emits `🎯 Composite match: /spec-driven-develop`. Composite-first is mandatory: invoke this, never its sub-skills by hand, because the sub-skills do not enforce the phase order, the reconciliation block, or the stop conditions.
- Another composite hands off a spec-shaped remainder ("the rest needs a real plan").

It does NOT fire on: trivial mechanical edits, read-only asks, or when a named lifecycle composite (hotfix, incident-response, release-cut, merge-confidently, debug-deep) matches. See Stop conditions.

## Why this exists

GitHub's spec-kit enforces a structured spec → plan → tasks → implement workflow via a `specify` CLI that scaffolds `.specify/` templates. This harness already has an equivalent skill for every phase — `adt-specs-spec-new`, `grill-with-docs`, `plan`, `plan-to-issues`, `dispatch`/`orchestrate`, `review`/`verify`. Installing the actual CLI would duplicate that coverage, add an external dependency, and fight the existing `docs/specs/<date>-<slug>/` convention. This skill gets spec-kit's discipline (explicit phases, no skipping straight to code) without the tool.

## Phase mapping

| Spec-kit phase | This skill's step | Sub-skill invoked |
|---|---|---|
| constitution | Phase 0 — confirm CLAUDE.md/CONTEXT.md exist for the repo; if `.harness/constitution.json` exists, treat it as the authoritative source (it, not `constitution.md`, is the enforced-invariants record) and also read `.harness/mcp-policy.json` when present; note gaps, don't block | (read-only check) |
| specify | Phase 1 — create/find the spec | `adt-specs-spec-new` → `docs/specs/<date>-<slug>/spec.md` |
| clarify | Phase 2 — resolve ambiguity inline | `grill-with-docs` |
| plan | Phase 3 — phased implementation plan | `plan` → `.claude/plans/<name>.md` (or `.agents/plans/`) — that skill's real output location; the persisted spec from Phase 1 is what carries forward past session scope, not this plan file |
| tasks | Phase 4 — externalize tasks if tracked work | `plan-to-issues` (skip if session-scoped, not tracked) |
| implement | Phase 5 — execute tasks, parallel where independent | `dispatch` / `orchestrate` / `loop` (mandatory parallel-execution rule applies) |
| analyze / converge | Phase 6 — gate before done | `review`, `verify`, `pr-merge-readiness` |

## Autonomy tiers per phase (ADR-0051)

`standards/autonomy-tiers.md` governs when a phase proceeds, self-gates, or asks. The phase order does not override it, and clearing Phase 2 (clarify) is not consent for Phase 5.

| Phase | Tier | Gate |
|---|---|---|
| 0 constitution, 1 specify, 2 clarify, 3 plan | T0 | none; proceed silently. Spec and plan files are written, not executed |
| 4 tasks | T1 | issues opened on own repos: proceed, report the links |
| 5 implement, narrow | T1 | branch commits, <5 files: proceed, report |
| 5 implement, wide | **T2** | ≥5 files or ≥2 modules, architecture / public API / schema / dependency changes: ONE adversarial critic pass (different tier than the executor, prompted to REFUTE, mechanical checks first), then proceed. Log the gate to `~/.claude/autonomy-gates.jsonl`. Escalate to the human only on unresolvable irreversibility or an auth/secrets/data-integrity boundary |
| 6 converge, merge or deploy | **T3** | merges to main, prod deploys, outward-facing publishes, and anything touching a PR authored by or commented on by another person: ask. No automation bypass |

Phase 6's critic pass is the T2 gate, not a debate panel: same-model panels rubber-stamp, and diversity of *checks* beats head-count. Do not substitute `/debate` for it.

**Read-only enforcement** (`standards/agent-routing.md`): Phases 0, 2 and 6 are analysis. Every agent dispatched in them carries a write-incapable `agentType` (`Explore`, `Plan`, `critic`, `code-reviewer`, `security-reviewer`, `document-specialist`). Only Phase 5 gets write-capable types. Findings from an analysis phase are applied by the orchestrator or by a separate implementer stage, never by the analysis agent.

## Reconciliation block (mandatory output)

Printed at the end of every run, including an aborted one. A run that "completed" without this block failed the contract (`standards/composite-contract.md`).

```
SPEC-DRIVEN DEVELOP

Scope:      <one line: what was built>
Spec:       <docs/specs/<date>-<slug>/spec.md | (skipped: <reason>)>
Plan:       <.claude/plans/<name>.md | (skipped: <reason>)>
Tier hit:   <highest tier reached: T0 | T1 | T2 | T3>
Critic:     <verdict + who ran it | n/a (no T2 phase)>

Phase status:
  0 constitution : DONE | SKIPPED (precondition <X> not met) | FAILED (<why>)
  1 specify      : ...
  2 clarify      : ...
  3 plan         : ...
  4 tasks        : ...
  5 implement    : ...
  6 converge     : ...

Verification:   <command + raw last line, per gate run>
Blockers:       <none | the blocker, as this skill's output>
Next:           <the smallest concrete next action>
```

A phase with no work to do is marked `SKIPPED (precondition <X> not met)`, never omitted.

## Stop conditions

- **Trivial edit** (<3 files, mechanical, no ambiguity): skip this pipeline entirely, go straight to `add` or a direct edit. Forcing the full phase sequence on a one-line fix is the exact overhead the "negative rules" in `skill-authoring.md` warn against.
- **Read-only ask** (audit, analysis, question): this skill doesn't apply — use the diagnostic skill directly.
- **A more specific composite matches** (hotfix, incident-response, release-cut, merge-confidently, debug-deep, or any other named lifecycle composite): defer to it. This skill is the default for build/add/fix/implement when nothing more specific matches, not a universal override — that exception holds regardless of how "mandatory" the default framing reads elsewhere.
- **Bailing mid-phase**: surface the blocker as this skill's output, mark the phase incomplete, resume next turn — never silently drop to ad-hoc editing (same contract as other composites, `standards/composite-contract.md`).

## Negative rules

- Do NOT invoke the sub-skills by hand instead of this composite when the router matched it. The chaining, the tier gates and the reconciliation block are the value; the sub-skills alone enforce none of them.
- Do NOT skip a phase because it "obviously has nothing to do". Mark it SKIPPED with the unmet precondition.
- Do NOT let Phase 5 implement what Phase 1 never specified. An unknown found mid-implementation goes back into the spec, not into ad-hoc mid-task research (same rule `/spec-research` hands to its executor).
- Do NOT treat a passed clarify phase as approval for a T2 or T3 action later in the chain. Tier the action, not the conversation.
- Do NOT dispatch an analysis phase with a write-capable `agentType`.
- Do NOT run this pipeline on a trivial edit. Forcing seven phases onto a one-line fix is the overhead `skill-authoring.md`'s negative rules exist to prevent.
- Do NOT end a run without the reconciliation block, including when bailing on a blocker.

## Interop with actual spec-kit projects

If a repo already has a `.specify/` directory (from someone using the real spec-kit CLI), read its templates as seed input for Phase 1 — but write output under `docs/specs/<date>-<slug>/`, not `.specify/`. Never install the `specify` CLI as part of this skill; that decision needs an explicit ask (new external dependency).
