# Reddit — r/ClaudeAI (Day 2 script)

Self-promo-friendly flair. Lead with the eval-gate demo, not the catalog. Reply
to every comment within 12h (launch-week discipline, launch-plan.md § Day 5-7).

## Title

Your Claude Code agent has no constitution. I built one that gates behavior in CI.

## Body

I kept hand-rolling `.claude/` config across machines and never trusting that
what I wrote down was what the agent actually did. No way to prove it, no way
to catch drift, no way to tell if a "small tweak" silently changed what the
agent was allowed to touch.

So I built sharekit: a portable profile that sits on top of whatever workflow
you already run (spec-kit, BMAD, plain Claude Code, doesn't matter) and adds
three things:

1. **A constitution** (`.harness/constitution.json` + a human-readable
   mirror) that defines what the agent can/can't touch, enforced before it
   acts, not audited after.
2. **A behavioral eval gate** that runs offline routing validation on every
   PR, and fails the >5pp regression check in CI when you wire in a key.
   Not code coverage, agent *behavior* coverage.
3. **MCP deny-by-default** so a new tool/server isn't reachable without an
   explicit, diffable approval you can review like any other PR.

Try it: `npx @lucassantana/sharekit install <your-repo>`

Not a framework, not a skill marketplace. You keep your workflow. This just
keeps the agent honest about what it's allowed to do, and proves it in CI
instead of asking you to trust it.

Happy to answer questions about how the eval gate actually catches a
regression, or the MCP policy format. Repo: [link]

## Send checklist

- [ ] Post Day 2, after Show HN (Day 1) has run
- [ ] Cross-post to OpenCode Discord same day
- [ ] Reply to every comment within 12h
- [ ] Win signal: "how does the eval gate work" / "what does the constitution check"
- [ ] Loss signal: "cool collection" / "nice skills" — if this dominates, positioning failed, don't iterate the product
