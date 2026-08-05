# Crawl-phase DM variants (launch-plan.md § Crawl, weeks 1-2)

Two variants, ~15 power users total, half each. Personalize the bracketed line per
recipient (reference their actual repo/setup) before sending, never send generic.
Track replies in the validation ledger (launch-plan.md § 3) by handle + variant.

Win signal: "how does the eval gate work" / "what does the constitution check."
Loss signal: "cool collection" / "nice skills."

## Variant A — governance angle

> Hey [name], saw [their .claude/ repo or post about hand-rolling agent config].
> I built sharekit after hitting the same wall: unversioned agent config with no
> way to prove it does what you think it does.
>
> It's a constitution file for your agent (what it can/can't touch, enforced not
> just documented) plus drift detection between machines. `npx @lucassantana/sharekit
> install [your-org/repo]` to try installing your own profile from it, or happy to
> just talk shop if you've solved this differently.
>
> [link]

## Variant B — compliance/CI angle

> Hey [name], noticed [their setup/post]. Curious how you're handling this: does
> your agent config get gated in CI anywhere, or is drift/regression something
> you catch by hand after the fact?
>
> I built sharekit to gate agent behavior the way you'd gate code: offline routing
> validation on every PR, a >5pp regression check when you wire in an OpenRouter
> key, plus a threat model and MCP deny-by-default policy you can diff in review.
> `npx @lucassantana/sharekit install [your-org/repo]` if you want to see the gate
> fire, or happy to compare notes.
>
> [link]

## Send checklist (per recipient)

- [ ] Confirm they're a genuine ceiling-moment case (public evidence of hand-rolled
      `.claude/`/`.opencode/` config, not just any Claude Code user)
- [ ] Personalize the bracketed reference line
- [ ] Log handle + variant + channel (X/Reddit/Discord) + date sent
- [ ] Reply within 12h per launch-week discipline
