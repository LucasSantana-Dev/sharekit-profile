# LinkedIn (Day 4 mirror, team/compliance audience)

Mirrors the Day 4 X thread thesis, adapted for the segment-2 audience
(security-conscious teams, platform/DevEx leads) per launch-plan.md's
accountability answer. No emoji, no thread format, one clean post.

## Post

Most teams adopting AI coding agents get stuck on one question that isn't
about the AI at all: **who's responsible when it does something wrong?**

Not "will it break something" — every team assumes it eventually will. The
real blocker is that nobody can answer who gets paged, who debugs it, or who
approved it being able to do that in the first place.

I built sharekit to answer that with artifacts your team can actually review,
not with an accuracy number:

- A **constitution** that defines what the agent can and can't touch, enforced
  before it acts. The "who gets paged" question becomes a policy review, not
  an incident.
- A **behavioral eval gate** wired into CI that fails on regression, the same
  review path your team already trusts for code.
- **MCP deny-by-default**: nothing new is reachable without an explicit,
  diffable approval. The approval log names the owner. No black box.

This isn't a framework and it isn't a skills catalog. It's a governance layer
you install on top of whatever agent workflow your team already runs.

If your team has an AI agent workflow and no good answer to "who owns this
when it goes wrong," that's exactly the gap this closes.

`npx @lucassantana/sharekit install <your-repo>` — or reply/DM, happy to walk
through the eval gate live.

[link]

## Send checklist

- [ ] Post same day as the Day 4 X thread, cross-link if the thread does well
- [ ] Target audience: platform/DevEx leads, security-conscious team leads
- [ ] Reply within 12h
- [ ] Win signal: comments/DMs asking about the accountability framing, incident process, or approval flow
- [ ] Loss signal: silence or "cool tool" with no follow-up question
