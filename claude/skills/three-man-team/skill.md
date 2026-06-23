---
name: three-man-team
description: |
  Parallel Architect→Builder→Reviewer pattern for complex features, big PRs, and multi-phase tasks.
  Dispatches 3 agents in parallel: Architect (Opus) writes detailed plan with phases + acceptance criteria;
  Builder (Sonnet) implements and stages changes; Reviewer (Sonnet) validates against plan + runs tests.
  Reduces 6+ sequential turns to 1 parallel dispatch for ≥3-phase work. Use when (1) task flagged CRITICAL,
  (2) feature estimated >2 hours, (3) multi-phase changes crossing >5 files requiring pre-build architecture review.
metadata:
  owner: global-agents
  tier: execution
  model: opus (architect), sonnet (builder/reviewer)
triggers:
  - three man team
  - architect builder reviewer
  - parallel build and review
  - complex feature
  - big pr
  - critical complexity

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
  - Read the relevant codebase modules and understand dependencies
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

## Example: Dispatch Pattern

```bash
# Invoke three agents in parallel (pseudo-code; actual tool call will depend on your agent platform)

agent dispatch \
  --name architect \
  --model opus \
  --prompt "Read the Lucky Discord bot codebase and write a plan for shipping /guild-config command. Details in task. Output to ~/.claude/plans/guild-config.md" \
  --task "Implement /guild-config command: allow server admins to set music genre filters, auto-disconnect timeout, and DJ role. 3 phases: (1) schema design, (2) command implementation, (3) integration tests."

agent dispatch \
  --name builder \
  --model sonnet \
  --prompt "Based on the Architect's plan at ~/.claude/plans/guild-config.md, implement the /guild-config command. Stage changes in worktree." \
  --task "Implement /guild-config command: allow server admins to set music genre filters, auto-disconnect timeout, and DJ role."

agent dispatch \
  --name reviewer \
  --model sonnet \
  --prompt "Read the Builder's staged changes and the Architect's plan at ~/.claude/plans/guild-config.md. Run tests. Check each phase acceptance criteria. Output a review summary." \
  --task "Implement /guild-config command: allow server admins to set music genre filters, auto-disconnect timeout, and DJ role."
```

All three run in parallel. Architect writes the plan. Builder and Reviewer can start immediately once the plan exists (or Builder starts and Reviewer waits).

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
