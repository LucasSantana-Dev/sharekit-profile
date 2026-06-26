# Three-Man-Team Dispatch Pattern

This shows how to invoke the three agents in parallel using pseudo-code (actual invocation depends on your agent platform).

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
