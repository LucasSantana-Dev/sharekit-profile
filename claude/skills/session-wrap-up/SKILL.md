---
name: session-wrap-up
description: Close out a development session by shipping work, capturing memory, and
  identifying follow-up improvements. Use when the session is ending and the user
  wants a disciplined wrap-up.
metadata:
  owner: global-agents
  tier: stateful
  canonical_source: $HOME/.agents/skills/session-wrap-up
---














# Session Wrap-Up

End your development session with comprehensive cleanup, shipping, and knowledge capture.

## Phase 1: Ship It

1. Run `git status` in all touched project directories
2. If uncommitted changes exist, create descriptive conventional commits
3. Push changes to remote repositories
4. Clean up temporary or experimental files

## Phase 2: Remember It

1. Review session for new insights or patterns
2. Update project documentation (README.md, CHANGELOG.md) if changes warrant it
3. Run `sync-memories` skill to persist session knowledge
4. Record new debugging techniques or solutions found

## Phase 3: Review & Apply

1. Identify tasks that were repeated and could be automated
2. Look for inefficiencies to prevent next time
3. Check for missing automation (scripts, CI steps, skills)
4. Write new rules or update project instructions for recurring patterns

## Phase 4: Publish It

1. Flag work worth sharing (blog posts, tutorials)
2. Prepare GitHub issues or PR descriptions if needed
3. Create reusable templates or examples

## Session Summary Template

```
## Session Summary
**Projects**: [list of projects touched]
**Changes**: [summary of key changes]
**Learnings**: [new insights discovered]
**Improvements**: [automation opportunities identified]
**Next Steps**: [suggested follow-up actions]
```

## Rules

- Run at the end of every meaningful session
- Ensure commits are meaningful and well-described
- Focus on capturing reusable knowledge
- Prioritize improvements that save time in future sessions

## Outputs / Evidence

- Return the concrete deliverable requested, the main decisions made, and any unresolved constraints.

## Failure / Stop Conditions

- Stop if required credentials, environment access, or prerequisite context are missing.
- Stop if the workflow would report unverified work as complete.
- Do not bypass required gates or safeguards unless the user explicitly asks for it.

## Memory Hooks

- Read memory before acting when queue state, repo history, or prior operational decisions affect correctness.
- Write back only durable conventions, confirmed outcomes, or workflow state worth reusing later.
