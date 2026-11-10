---
name: grill-with-options
description: "Interview skill with four modes: options (default, bounded 2-4 option AskUserQuestion forks), open (Q plus GUESS), docs (vs CONTEXT.md and ADRs), explore (2-3 approaches, no code). Use for grill me, help me decide, brainstorm."
triggers:
  - grill-with-options
  - grill-me
  - grill-with-docs
  - brainstorming
  - grill me
  - interview
  - help me decide
  - pick path
  - bounded options
  - decision interview
  - trade-offs
  - stress-test plan
  - stress-test design
  - convergence interview
  - challenge plan against domain
  - sharpen terminology
  - update documentation inline
  - brainstorm
  - idea exploration
  - design direction
  - rough concepts
---

# Grill With Options

One interview skill, four modes. Interview the user through a plan or design until you can predict their answers to the next three questions you would ask. That is convergence, not a vibe.

## Mode selection

Pick the mode from the request; if unclear, use `options`. Never ask the user which mode to use.

| Mode | Use when | Replaces | Detail |
|---|---|---|---|
| `options` (default) | Forks are enumerable. Surface each as a bounded `AskUserQuestion` with 2-4 options (the owner prefers this). | this skill | this file |
| `open` | Forks are not yet enumerable: vague plan, "grill me", "interview me". One question at a time, each with your GUESS. | `grill-me` | [mode-open.md](./references/mode-open.md) |
| `docs` | A repo has `CONTEXT.md` / ADRs, or the user says "against our domain docs". Challenge the plan against the glossary, sharpen terms, flag term conflicts, update `CONTEXT.md` and ADRs inline per the ADR gate. | `grill-with-docs` | [mode-docs.md](./references/mode-docs.md), [CONTEXT-FORMAT.md](./references/CONTEXT-FORMAT.md), [ADR-FORMAT.md](./references/ADR-FORMAT.md) |
| `explore` | The user is still shaping the solution: "brainstorm", rough notes. Divergent 2-3 approaches with trade-offs and a recommendation, constraints surfaced. | `brainstorming` | [mode-explore.md](./references/mode-explore.md) |

Read the mode's reference file before starting that mode. Modes combine: `open` or `docs` may switch to `options` for any fork that becomes enumerable; `explore` ends by handing a chosen direction to `plan`.

Do not interview (any mode):

- Pure information questions (for example "what does HTTP 409 mean?") get a direct answer.
- An implementation the user already decided (for example "we chose exponential backoff, 5 attempts, write it") gets built, not grilled.

Precedence: when the repo has `CONTEXT.md`/ADRs AND the user asks to decide between options, use `docs` mode (docs wins; say so in one line).

Hard gates per mode (all survive the merge):

- `options`: halt in non-interactive contexts; one fork per turn; restate and get an explicit yes.
- `open`: exactly one question per turn in Q/GUESS shape, then stop and wait; never answer your own question or rewrite the plan.
- `docs`: ask one question at a time with a recommended answer; never ask what `CONTEXT.md` already answers; no ADR unless all three ADR criteria hold (hard to reverse, surprising without context, real trade-off); `CONTEXT.md` stays a glossary.
- `explore`: no code and no implementation action until a design direction is approved; at most one clarifying question per turn.

## When to Use (options mode)

- A plan has forking decisions where the alternatives are knowable in advance
- The user says "help me decide", "grill me with options", "pick-path", or "walk me through the trade-offs"
- Bounded choices will resolve ambiguity faster than open text (architecture decisions, UX flows, deployment strategies, API contract choices)
- You want to stress-test a plan without burdening the user with blank-slate thinking

## When NOT to Use

- Non-interactive contexts (CI, `/loop`, autonomous runs): see Failure Conditions instead
- Decisions where the user genuinely has free-form input that can't be bounded (naming things, writing copy)
- ≥95% confidence already exists, don't manufacture doubt
- Questions the codebase answers (`standards/workflow.md`, explore first, ask second)
- Mechanical operations with no real trade-off

## How to Run a Session

### 1. Map the decision tree first (silently)

Before asking anything, identify the top-level forks in the plan. A fork is a decision point where choosing one path forecloses others. Don't ask about leaf-level details until the trunk decisions are settled, later choices depend on earlier ones.

Explore the codebase if one exists. Don't ask what `git log`, `grep`, or a config file can answer.

**Done when:** You have identified ≥2 top-level forks and mapped their dependencies (which later decisions depend on which earlier choices).

### 2. Ask one fork at a time

Use `AskUserQuestion` for each fork. Present the decision as one question with 2-4 options. Then wait for the answer before moving to the next question.

**Why one at a time:** later questions depend on earlier answers. Batching locks in the wrong framing for downstream questions and prevents you from pruning branches the user just closed.

**Done when:** User has selected one option and you have mapped the next fork(s) that decision unlocks.

### 3. Design each question well

**Header (≤12 chars: hard UI limit):** The `AskUserQuestion` header renders as a small chip/tag in the interface; anything over 12 characters is clipped by the UI. **Before finalizing any header, count its characters.** If the count is ≥ 11, find a shorter synonym before writing it. `Orchestration` = 13 → `Delivery` (8). `Observability` = 13 → `Monitoring` (10). Examples that fit: `Storage` (7), `Auth` (4), `Deployment` (10), `API style` (9).

**Single-select** when options are mutually exclusive, picking one forecloses the others.

**Multi-select** when the user can pick several that apply, acceptable failure modes, desired features, constraints to honor.

**Option labels:** 1-5 words, the choice itself.

**Option descriptions:** explain the *consequence* of this choice, not a definition of it. "You'll own schema migrations; harder to change later" beats "A relational database." Surface the trade-off.

**Option previews** (optional): use for visual comparisons, ASCII architecture diagrams, contrasting code snippets, config examples. Only when seeing it side-by-side genuinely helps the decision; skip for preference questions where labels + descriptions suffice.

**Recommended option:** if one is clearly better given what you know, make it first and label it "(Recommended)".

**Done when:** Question is phrased, ≥2 options drafted with consequence-based descriptions, and UI constraints verified (header ≤12 chars, single/multi-select chosen).

### 4. Adapt the tree as selections arrive

Prune branches the selection forecloses. Promote questions whose context is now settled. Don't ask about a consequence you can infer from a prior answer.

### 5. Non-answer handling

Some selections don't count as convergence:

- User picks "Other" and types something vague → reframe with two concrete options derived from what they wrote
- User picks every option in a single-select → they're uncertain; split into two forks
- Selections plateau (you're looping the same fork) → something foundational is missing; see Floor Stop below

**Done when:** User's selection is unambiguous and you have adapted the remaining tree or identified the next fork to ask.

## Stop Conditions

### Primary stop (success)

The 95% predictive test: you can confidently predict which option the user would pick for the next three questions you'd ask. When that's true, **restate** the decisions made:

- **Outcome:** what success looks like
- **Key decisions:** list each fork resolved and what it forecloses
- **Constraint:** what must hold
- **Out of scope:** what you're explicitly not building

Get an explicit "yes" before moving on.

**Done when:** User confirms the restatement, the decision tree is fully resolved, or they indicate ready to proceed.

### Floor stop (failure to converge)

Several rounds without the decision tree narrowing → something foundational is missing. Pause:

> "I've asked N questions and the choices keep reopening. Something foundational is underspecified. Want to step back and define it?"

Don't grind on the same forks.

**Done when:** User either steps back to define foundation or confirms they want to proceed with ambiguity.

## Failure Conditions (options mode)

Halt and surface the blocker if any of these occur. `docs`/`explore` invoked by another skill in autonomous mode (for example resolve-before-asking, research-and-decide): self-answer each round and record assumptions; do not halt.

- **Non-interactive context** (CI, `/loop`, autonomous agent run): user cannot respond in real time. Surface: "This skill requires interactive user input (AskUserQuestion); not available in this context."
- **User declines to answer** (picks "Other", gives vague input, or refuses all options repeatedly): divergence, not convergence. Surface: "Your responses suggest bounded options aren't framing this correctly. Want to switch to open mode (one question plus GUESS) instead?"
- **No clear forks exist** (the plan has no real trade-offs, or codebase already answers the decisions): this skill is the wrong tool (single-term docs checks are exempt). Surface: "This doesn't appear to have decision forks; suggest [grep/ADR review/code read] instead."
- **External HD unmounted** (if skill later links to RAG/vault): knowledge lookup fails silently. Check: `mount | grep -q "${DEV_ROOT:-$HOME/dev}"` before any rag_query/search_knowledge. Surface: "External HD unmounted, knowledge lookup blocked; cannot proceed."

Do not silently fall back; halt and tell the user which condition blocks progress.

```
AskUserQuestion({
  questions: [{
    question: "Where should user sessions be stored?",
    header: "Sessions",
    multiSelect: false,
    options: [
      {
        label: "Database (Recommended)",
        description: "Survives restarts, works across replicas. You'll need a sessions table and cleanup job."
      },
      {
        label: "Redis",
        description: "Faster reads, lower DB load. Adds an infrastructure dependency and a failure mode."
      },
      {
        label: "JWT (stateless)",
        description: "No server-side state. Revocation is hard, a leaked token stays valid until expiry."
      }
    ]
  }]
})
```

For visual comparisons, add a `preview` field with an ASCII diagram or code snippet so the user can see the difference rather than read about it.

## Convergence Check (internal, every turn)

After each answer, ask yourself: *If I were to ask the next three questions, could I predict the answers?* If yes, restate and stop. If no, ask the next fork.

This is a checkable test, not a feeling.

---

## References

- `standards/skill-authoring.md`, 13-point checklist (this skill compliance).
- `standards/workflow.md`, explore-first discipline; when to defer user input.
- CLAUDE.md, signal-first output rule (verdict + top 3 findings inline).
