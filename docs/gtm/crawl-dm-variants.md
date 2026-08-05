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

## Sent log

| Handle | Channel | Variant | Date | Delivery | Notes |
|--------|---------|---------|------|----------|-------|
| u/shhdwi | Reddit DM | Custom (Graft-specific, tool-governance angle) | 2026-08-05 | Sent | Built Graft (NanoNets), 865 stars. Their post: Claude Code silently ignores MCP tools rather than erroring, "sent me looking in the wrong place for weeks." Pitched sharekit as the adjacent problem (what's reachable + behavior gating) rather than a competitor to Graft. |
| u/Known_Isopod_1581 | Reddit comment (DM blocked, account restricts message requests) | Custom (Rootpilot-specific, boundary-check angle) | 2026-08-05 | Sent as public comment | Built Rootpilot, a Claude Code orchestration app. Their post: "context drift is real," strict boundary checks per execution slice cut hallucinated features. Post explicitly invited comments/DMs. Comment posted under u/LukDoLolo on their thread. |
| u/Wise_Resource_8648 | Reddit DM | Custom (governance/eval gate angle) | 2026-08-05 | Sent | Subject: "sharekit: same category, different angle (governance/eval gate)". |
| u/funkadelic1 | Reddit DM | Custom (config-sync angle) | 2026-08-05 | Sent | Subject: "sharekit: syncing config is half the problem". |
| u/LegitimateManner3087 | Reddit DM | Custom (deny-by-default angle) | 2026-08-05 | Replied | Subject: "sharekit: deny-by-default would've stopped that key grab". Reply (14:18): pointed to their own project mcpvessel (deny-by-default MCP container sandboxing), asked for a look/star. Followed up (16:00): positioned as complementary (mcpvessel contains blast radius post-grant, sharekit's constitution decides the grant), asked how Vesselfile handles a server requesting new permissions mid-run. No reply yet to the follow-up. Star not actioned, not requested by operator. |
| u/zimxero | Reddit DM | Custom (Context Harness, memory-persistence angle) | 2026-08-05 | Sent | Subject: "sharekit: memory survives sessions, does your governance?". Built Context Harness, file-based persistent memory across sessions; pitched sharekit as the adjacent problem, persisted permissions/behavior needing the same re-check as persisted context. |
| u/weltern | Reddit DM | Custom (Clawdmeter, usage-vs-behavior angle) | 2026-08-05 | Sent | Subject: "sharekit: Clawdmeter measures usage, we gate behavior". Built Clawdmeter, a Claude Code usage/cost tracker; pitched sharekit as the adjacent axis, visibility into usage vs. gating what the agent is allowed to do. |
| u/MirafoldHQ | Reddit DM | Custom (Mirafold, orchestration-layer angle) | 2026-08-05 | Replied | Subject: "sharekit: same instinct as Mirafold, different layer". Built Mirafold, an agent orchestration/workflow tool; pitched sharekit as one layer down, constitution + eval gate vs. orchestration correctness. Reply (14:18): pushed back, Mirafold doesn't govern the agent, just renders output more polished ("trains the wild horse vs. combs its hair"), open to the tools working together. Followed up (16:00) reframing as stacked, not competing, asked if Mirafold ever surfaces an agent that renders well but acted out of scope. Reply (16:05): "In its current form that's out of its lane. But stacking these is exactly what I had in mind." Positive close, no further action needed unless pursuing an integration angle. |
| u/toshipepe | Reddit DM | Custom (Tokimeter, visibility-vs-permission angle) | 2026-08-05 | Replied | Subject: "sharekit: Tokimeter tracks the clock, we gate the actions". Built Tokimeter, a Claude Code time/usage tracker; pitched sharekit as the permission half of the visibility problem. Reply (12:53): "cool will check it out", low-signal, no question, no follow-up sent. |
| u/PutFun1491 | Reddit DM | Custom (sandbox self-tests, policy-vs-isolation angle) | 2026-08-05 | Sent | Subject: "sharekit: sandbox tests the run, constitution scopes it". Built sandbox self-tests for verifying agent actions in isolation; pitched sharekit as the policy-side complement to sandbox isolation. |

All sourced via live Reddit research (r/ClaudeAI, r/ClaudeCode), verified directly
(post + username checked in-browser, not taken from an automated summary at face
value) before drafting or sending.
