---
name: context-save
description: Capture the current task state so the work can be resumed later without
  losing key decisions, blockers, or next steps. Use when the session may be interrupted
  or the user explicitly wants resumable context saved.
argument-hint: '[<note>]'
metadata:
  owner: global-agents
  tier: stateful
  canonical_source: $HOME/.agents/skills/context-save
---














# Context Save — Mid-Task State Preservation

Serialize current task progress, decisions, and next steps to a recoverable file. Different from `sync-memories` (end-of-task documentation) — this is mid-task insurance against context loss.

## When to Use

- Manually: when you sense context is getting large
- Proactively: AI should invoke this when approaching context limits
- Before risky operations that might require a session restart

## Execution

### 1. Gather State (parallel shell calls)

```bash
cd <cwd> && git branch --show-current && git status --short && git log --oneline -3
cd <cwd> && git diff --stat HEAD 2>/dev/null | tail -20
ls -t .agents/plans/*.md .claude/plans/*.md 2>/dev/null | head -1
```

### 2. Synthesize Progress File

Write to `.agents/memory/in-progress.md`:

```markdown
# In-Progress Task — <timestamp>

## Task
<What was being worked on>

## Current Step
<Which phase/step of the plan we're on>

## Completed So Far
- <Bullet list of what's done with commit SHAs, PR numbers, file paths>

## Next Steps
1. <Immediate next action with specific file paths>
2. <Following actions>

## Key Decisions Made
- <Decision and rationale>

## Open Issues
- <Anything blocking or uncertain>

## Files Modified (uncommitted)
<output of git diff --stat>

## Branch
<current branch name>
```

### 3. Also Update Task Queue

If there's an active claimed task in `.agents/task-queue.json`, add a `notes` field with current progress summary.

### 4. Confirm

```
Context saved to .agents/memory/in-progress.md
Branch: <branch>, Step: <current step>
Resume with the resume skill in a new session.
```

## Rules

- Write to memory directory, NOT to the repo
- Overwrite previous in-progress.md (only one active task at a time)
- Include enough detail that a fresh session can continue without re-reading files
- Keep it factual — decisions, paths, SHAs — not narrative

## Outputs / Evidence

- Return the concrete deliverable requested, the main decisions made, and any unresolved constraints.

## Failure / Stop Conditions

- Stop if key prerequisites are missing or the request changes scope enough that the current workflow no longer fits.

## Memory Hooks

- Read memory before acting when queue state, repo history, or prior operational decisions affect correctness.
- Write back only durable conventions, confirmed outcomes, or workflow state worth reusing later.
