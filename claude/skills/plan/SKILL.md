---
name: plan
description: |
  Build a compact, validation-gated implementation plan when work is multi-phase, cross-file, risky, or ambiguous.
  Use when: planning a rollout sequence, designing a phased migration, or when stakeholder alignment before coding reduces rework.
  Phases → explicit validation gates + replanning triggers. Output to `.claude/plans/<topic>.md`.
  Skip: trivial fixes (inline edit), bug hunts (→ tracer), exploration (→ explore).
metadata:
  tier: execution
  owner: lucas
  canonical_source: ~
triggers:
  - create a plan
  - plan this
  - draft a plan
  - design the rollout
  - phase this work
  - implementation strategy
  - what is the approach
---

# plan

Build compact, validation-gated plans for multi-phase work. Use only when reducing pre-execution risk outweighs the cost of planning.

## Steps

**Step 1: Query existing decisions.** (DONE WHEN: checked for related prior plans/ADRs or no vault mounted)

Run if External HD mounted:
```bash
mount | grep -q "${DEV_ROOT}" && \
  python3 ~/.claude/rag-index/query.py "scope of <topic> / rollout strategy for <topic>" --top 3 --scope handoffs --fast
```
Read `.claude/plans/` for current topic. If a conflicting plan exists, surface blocker and halt — don't replan.

**Step 2: Read local guidance.** (DONE WHEN: CLAUDE.md, README.md, .claude/standards/ scanned for scope/constraints)

Scan: `.claude/CLAUDE.md` (storage policy, parallel rules, hard constraints), `.claude/plans/` (active work), `.agents/memory/` (session state).

**Step 3: Clarify ambiguities.** (DONE WHEN: ≥1 material unknowns resolved or explicitly flagged as out-of-scope)

List unknowns in the request: scope boundaries, stakeholders, success criteria, constraints, blockers. Resolve each or mark `flagged — confirm with user`. **Stop here if ≥1 material ambiguity cannot be resolved — do NOT plan over a guess.** Surface the blocker and halt.

**Step 4: Draft scope, phases, validation.** (DONE WHEN: goal + in/out-of-scope stated; ≥2 phases with per-phase completion criteria listed)

- **Goal:** 1-sentence outcome.
- **In-scope:** files/services touched, decisions to make, deliverables.
- **Out-of-scope:** what won't happen, related work deferred.
- **Phases:** each phase ≤ 1–2 days of work; each ends with a testable done-condition ("all tests passing", not "ready").
- **Replanning triggers:** what would signal scope creep or failure.

**Step 5: Critic gate — challenge the draft before writing it.** (DONE WHEN: critic verdict returned AND every critical issue resolved or explicitly accepted; recorded under a `## Critic notes` subsection in the plan)

After the draft exists but BEFORE Step 6, dispatch **ONE read-only `Explore` agentType subagent** (never edits — it can only return findings) to challenge the plan with these seed questions:

> "Challenge this plan: (1) Which phase has a completion criterion that could pass while the real work is unfinished? (2) What dependency or affected file is unstated? (3) What is the most likely reason this plan needs replanning, and is that trigger captured?"

- **Bounded:** at most **2** revise→re-challenge iterations. If critical issues remain unresolved after 2, **proceed-or-escalate** — write the plan with the open issues recorded under `## Critic notes` and surface them to the user (do not loop further; see the Stuck protocol).
- If the critic finds only minor concerns → log them under `## Critic notes` and proceed.
- Output location: append the critic's verdict + any accepted-risk items to a `## Critic notes` subsection of the plan file written in Step 6.

(This replaces a self-review with an independent maker≠checker challenge — a confident plan is not a correct one.)

**Step 6: Write to disk.** (DONE WHEN: `.claude/plans/<topic>.md` or `.agents/plans/<topic>.md` written, INCLUDING the `## Critic notes` subsection from Step 5; commit not required)

Use template at `references/plan-template.md`. Include: goal, scope, phases (with per-phase validation + replanning triggers), dependencies, current state (if partially done).

## Stop conditions (halt & surface blocker — do not proceed to next step)

- **External HD unmounted:** RAG unavailable; proceed with Step 2 only (local guidance).
- **Material ambiguity unresolved:** surface ambiguity, halt before Step 4.
- **Plan already exists & unchanged:** surface "plan exists at <path>" — validate user intent to replan before restarting.

## Auto-chain

After writing: pair with `/ship` if merge/release is the next phase. If plan uncovers architectural gaps, queue `/research-and-decide` (critic review) before phasing further.

## Cross-references

- Template: `references/plan-template.md`
- Scope gate design: `standards/decision-discipline.md §2`
- Validation anatomy: `standards/testing.md §1` (done-condition patterns)
