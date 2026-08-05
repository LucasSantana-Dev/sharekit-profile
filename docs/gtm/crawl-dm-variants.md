# Crawl-phase DM variants (launch-plan.md § Crawl, weeks 1-2)

Two variants, ~15 power users total, half each. Personalize the bracketed line per
recipient (reference their actual repo/setup) before sending, never send generic.
Track replies in the validation ledger (launch-plan.md § 3) by handle + variant.

Win signal: "how does the eval gate work" / "what does the constitution check."
Loss signal: "cool collection" / "nice skills."

## Variant A — governance angle (PAS)

> Hey [name], saw [their .claude/ repo or post about hand-rolling agent config].
> Quick question: if that config silently stopped enforcing something tomorrow,
> how would you find out? For most hand-rolled setups the honest answer is
> "whenever it breaks in front of someone," not before.
>
> That's the wall I hit, so I built sharekit: a constitution file for the agent
> (what it can/can't touch, enforced not just documented) plus drift detection
> between machines, so the gap between "written down" and "actually enforced"
> is a diff, not a surprise. `npx @lucassantana/sharekit install [your-org/repo]`
> to try installing your own profile from it, or happy to just talk shop if
> you've solved this differently.
>
> [link]

## Variant B — compliance/CI angle (PAS)

> Hey [name], noticed [their setup/post]. Does your agent config get gated in
> CI anywhere, or is drift/regression something you only catch by hand after
> the fact? Most teams find out about a config regression from a user, not
> from a check, because nothing gates agent *behavior* the way tests gate code.
>
> I built sharekit to close that gap: offline routing validation on every PR,
> a >5pp regression check when you wire in an OpenRouter key, plus a threat
> model and MCP deny-by-default policy you can diff in review, same review
> path as any other failing check. `npx @lucassantana/sharekit install
> [your-org/repo]` if you want to see the gate fire, or happy to compare notes.
>
> [link]

## Send checklist (per recipient)

- [ ] Confirm they're a genuine ceiling-moment case (public evidence of hand-rolled
      `.claude/`/`.opencode/` config, not just any Claude Code user)
- [ ] Personalize the bracketed reference line
- [ ] Log handle + variant + channel (X/Reddit/Discord) + date sent
- [ ] Reply within 12h per launch-week discipline
