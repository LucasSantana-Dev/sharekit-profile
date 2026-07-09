---
name: three-man-team
description: "Parallel Architect→Builder→Reviewer pattern for complex multi-phase tasks. Dispatches 3 agents: Architect (Opus) reads codebase and writes a plan with phases; Builder (Sonnet) implements from plan and stages changes; Reviewer (Sonnet) validates diff and runs tests. Cuts turnaround on 3+ phase features and big PRs from 6+ turns to 1-turn dispatch. Use when phases justify the overhead; when CRITICAL-flagged; or for large PRs touching >5 files."
tags:
- parallel-dispatch
- architecture
- implementation
- code-review
- multi-phase
platforms:
- Claude
metadata:
  owner: global-agents
  tier: orchestration
  canonical_source: ~/.agents/skills/three-man-team
triggers:
  - parallel team
  - three person team
  - big pr
  - multi phase
---

## When to Use

- **Tasks flagged CRITICAL** by complexity-classifier
- **Estimated >2 hours** of work
- **Multi-phase features** (3+ distinct phases: design, build, test)
- **Large PRs** touching >5 files
- **Cross-module changes** requiring architectural review before implementation

## When NOT to Use

- Simple bug fixes (<30 min)
- Single-file changes
- Refactoring with clear, linear steps
- Anything already well-scoped in an existing plan

---

## How It Works

Three agents run in parallel, each with a specific role:

### Agent 1: Architect (model: opus)
- **Input**: task description, codebase context, current branch state
- **Job**: 
  - Read the relevant codebase modules and map module interdependencies; identify breaking-change risks and flag hidden coupling
  - Identify phases, boundaries, and architectural decisions
  - Write a structured plan to `~/.claude/plans/<task>.md`
- **Output**: `~/.claude/plans/<task>.md` with:
  - Objective & scope
  - Phase breakdown (Phase 1, Phase 2, etc.)
  - Acceptance criteria per phase
  - Implementation boundaries (what Builder should NOT touch)
  - Known constraints & gotchas
  - Links to relevant code/docs

### Agent 2: Builder (model: sonnet)
- **Input**: Architect's plan, task description
- **Job**:
  - Implement based on the plan
  - Write code, tests, commit messages
  - Stage all changes in a worktree or branch
  - Prepare PR description
- **Output**: PR-ready code (or staged changes + PR branch)

### Agent 3: Reviewer (model: sonnet)
- **Input**: Builder's diff/staged changes, Architect's plan
- **Job**:
  - Compare changes against plan acceptance criteria
  - Run test suite
  - Check for regressions or scope creep
  - Flag issues as comments on the diff
  - Approve or request changes
- **Output**: review summary with pass/fail per phase + blocking issues (if any)

---

## Stop Conditions

**Stop if:** Architect plan missing or unparseable → surface `BLOCKED: Architect plan not readable at ~/.claude/plans/<task>.md. Missing: valid plan file with phases, boundaries, and acceptance criteria. Next: verify Architect completed; re-run if needed before dispatching Builder and Reviewer.`

---

## Dispatch Pattern

See [references/dispatch-pattern.md](references/dispatch-pattern.md) for the pseudo-code invocation and parallel execution flow.

**Result**: Complex feature planned, implemented, and validated in ~3 turns instead of 10+.

---

## Acceptance Criteria

✅ All three agents complete without errors  
✅ Architect's plan includes phase breakdown & acceptance criteria  
✅ Builder's changes align with plan scope  
✅ Reviewer confirms all acceptance criteria met  
✅ Tests pass with >90% coverage on new code  
✅ PR ready for human review

---

## Integration Notes

- Use with `/dispatch` or `/orchestrate` skill to invoke agents
- Architect should write to `~/.claude/plans/<task-name>.md` so Builder and Reviewer can read it
- Builder should use a git worktree for isolation
- Reviewer should produce a summary comment or checklist for the PR
- If Reviewer flags issues, Builder can update and loop Reviewer again
