---
name: xp
description: "Extreme Programming for AI-human pair development. Use when: pair programming with your AI, building incrementally with tests, working with clear role division, or the user mentions XP/YAGNI/simple design/continuous refactoring."
metadata:
  tier: "methodology"
  owner: "lucas"
  canonical_source: "https://github.com/<github-user>/claude-code"
triggers:
  - xp
  - pair programming
  - extreme programming
  - continuous refactoring
---

# XP — Extreme Programming with AI Agents

XP adapted for AI-human pairs: continuous code review (live pairing), relentless testing (TDD), constant design improvement (refactoring), frequent releases (small increments). See [philosophy.md](references/philosophy.md) for foundational values.

## When to Invoke

- **Pair dev** — User wants structured iteration with tests + review (no big-bang implementation)
- **Incremental features** — Break work into 5-min cycles; each cycle: plan → test → code → refactor
- **Roles unclear** — Need to signal who drives (direction) vs. navigates (reviews); see [roles.md](references/roles.md)
- **Refactor needed** — Existing code quality degradation; XP treats refactoring as continuous, not deferrable
- **Not a fit** — Stop if: user wants a quick script (no test overhead), one-off task (no iteration), or user is not engaged for review

## Workflow (One Cycle)

### 1. Plan — Pick ONE Small Task

Define a single, deliverable piece of work. Confirm with human:
- **What** (acceptance criteria)?
- **Why** (business value)?
- **How** (constraints, conventions)?

**Done when:** Human approves the task before coding starts.

### 2. Test — Write One Failing Test

Write a test that describes behavior, not implementation. It must fail first. See `/tdd` for full red-green-refactor discipline.

**Done when:** Test runs, fails predictably, human reviews & approves the test.

### 3. Implement — Minimal Code to Pass

Write the simplest code that makes the test pass. No over-engineering. If multiple approaches work, pick the clearest.

**Done when:** Test passes; all other tests still pass; no lint errors.

### 4. Refactor — Improve While Green

Extract duplication, clarify names, simplify structure. Never refactor while red.

**Done when:** All tests pass; code is noticeably simpler/clearer than step 3.

### 5. Release — Commit the Increment

Small, focused commit. Then return to step 1 (pick next task) or hand off. See CLAUDE.md [pr-conventions.md](file://~/.claude/standards/pr-conventions.md) for commit style.

**Done when:** Commit is pushed or staged; human has reviewed the diff.

## Continuous Practices

Running throughout every cycle:

- **Read before write.** Explore project structure, conventions, and the area you're changing before proposing changes.
- **Run tests + lint after every change.** Discover and fix failures immediately (CI automation: see CLAUDE.md [workflow.md](file://~/.claude/standards/workflow.md#continuous-integration)).
- **Communicate intent.** Explain approach and tradeoffs *before* coding, not after.
- **Stay small.** If a cycle takes >30 min, split the task.

## Handoff Contract

After one or more completed cycles:

1. **Pairing outcome** (signal-first; CLAUDE.md [signal-first rule](file://~/.claude/standards/workflow.md#signal-first-output))
   - Verdict: features working / tests green / ready for review
   - Top 3 blockers (if any)
2. **Code state** — All diffs staged or on branch, tests passing
3. **Next task** — Pick, or hand to human for re-prioritization

If > 3 cycles in a session, use `/handoff` to checkpoint (memory, ADR, next priorities).

## References

- [philosophy.md](references/philosophy.md) — Five XP values (Communication, Simplicity, Feedback, Courage, Respect) + their AI adaptations
- [practices.md](references/practices.md) — The 12 XP practices (Pair Programming, Planning Game, TDD, Whole Team, etc.) + guidance per practice
- [roles.md](references/roles.md) — Driver/Navigator role dynamics, anti-patterns (Yes Machine, Ghost Pair, Scope Creep), healthy pairing checklist
- See `/tdd` for the detailed test-driven development loop (red-green-refactor)
- See `/handoff` for multi-session checkpointing
