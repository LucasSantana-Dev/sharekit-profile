# sharekit-profile: Detailed Ads Campaign Plan

**Status: PLANNING ONLY. No spend approved. Requires G1-G5 pass + explicit operator go-ahead before launch.**

Date drafted: 2026-08-05. Tied to `docs/gtm/launch-plan.md` section 4 (Ads Plan Phase 3). 

---

## Channel Assessment & Fit

### Primary channels (ranked)

**1. Reddit Ads (r/ClaudeAI + r/ChatGPTCoding): HIGHEST FIT**

Why: Audience is self-selected Claude Code users, native to dev-tool discourse, skeptical of polished marketing. Reddit rewards raw value messaging ("your agent has no constitution") over slick brand speak.

- CPM: $5-15 (mid-tier dev subreddits; r/ClaudeAI skews lower, ~$6-10)
- CPC: $0.50-1.50
- Subreddit rules: self-promo allowed with flair; r/ClaudeAI moderation is permissive
- Creative approach: ads read like organic posts (governance/eval story, not skill inventory)

**2. X/Twitter Ads: HIGH FIT**

Why: Anthropic-adjacent community, agent-tooling conversation hub. Links outperform images/engagement metrics for dev audiences. Targeting: followers of Anthropic, OpenCode, agent-tooling accounts.

- CPM: $5-10 (competitive, dev-oriented)
- CPC: $0.50-2.00 (wide range; link clicks are the metric, not impressions)
- Creative: threads that mirror organic win conditions ("why eval gates matter", "how eval gates caught a routing regression in CI")

**3. Newsletter Sponsorships (curated rotation): MEDIUM-HIGH FIT**

Why: Direct inbox, pre-filtered audience of active devs, best click-quality per dollar. One-send sponsorship cost yields higher engaged signups than equivalent Reddit budget.

- Cost: $300-1,500 per send (rotate TLDR AI, Pointer.io, The Batch, AI engineering-focused newsletters)
- Conversion: highest CTR and intent-qualified traffic in this tier
- Sponsor slot: "native ad" format (written as editor-like note, not banner)
- Constraint: newsletter sponsorship is a commitment, not a per-message buy. Tie to test tier only after G3 passes (install-to-engagement proven).

**4. Google Ads (long-tail keywords): LOW-MEDIUM FIT**

Why: Capture high-intent searchers ("how to configure claude code", "claude code hooks"), but volume is tiny. Use as a defensive hold, not growth engine.

- CPC: $1-3 (dev keywords are competitive)
- Keywords: "claude code config", "claude code hooks", "opencode configuration", "agent governance", "claude code security"
- Volume: estimate 10-30 searches/month across entire keyword set combined; capture <5 clicks/month organically at best
- Budget: minimal ($30-50/month); oversizing wastes budget on irrelevant clicks

**5. NOT RECOMMENDED: Meta (Facebook/Instagram)**

Assessment: **Poor fit. Recommend rejecting outright.**

- Audience mismatch: Facebook/Instagram targeting is demographic/lifestyle-based ("25-44, interested in tech"). Claude Code users concentrate on Reddit/X/dev communities, not Facebook feeds.
- Brand risk: Meta's algorithm optimizes engagement-at-all-costs; governance/security messaging ("your agent has a constitution") does not resonate on visual feeds and may be misserved to non-technical audiences.
- CAC unfavorable: CPM $3-6 (lower cost) but CPC $1.50-4.00 for dev-tool creative; conversion to install is worse than X/Reddit (audience is less intent-qualified).
- Positioning misalignment: the "AI teammate you can audit and gate" story requires technical detail; Instagram's 3-5 second attention span and visual-first model contradicts this entirely.
- Incumbent pattern: no developer-tool wins on Meta as primary channel (contrast: Linear, Vercel, Supabase all skew Reddit/X for early stage, rarely Meta). The loss pattern is baked in.

**Recommendation:** Remove from testing entirely. Allocate budget to Reddit + newsletter rotation instead.

---

## Creative Briefs by Channel

### Reddit Ads

**Variant A: "Eval Gate" (governance angle)**

*Copy:*
```
Your Claude Code agent has no constitution.

That means: secrets can leak, hooks can drift, routing can silently degrade, and you won't catch it until prod breaks.

sharekit installs one CI gate that catches agent-behavior regressions the same way your test suite catches code regressions.

npx @lucassantana/sharekit install
```

*Visual:* Side-by-side screenshots. Left: red X on a routing regression caught by CI. Right: workflow badge "gates pass". Simple, no designer needed; animated GIF ~2sec loop.

*Targeting:* r/ClaudeAI, r/ChatGPTCoding (subreddit placement), exclude accounts with <100 karma (spam filter).

**Variant B: "Governance as Code" (compliance angle)**

*Copy:*
```
You hand-rolled your .claude/ config to stay in control.

But there's no version control, no diff visibility, no CI gate, and the next time your setup breaks, you're debugging from scratch.

sharekit brings governance-as-code: a constitution.json you version and gate, a threat model you can read, and an eval gate that catches drift before prod.

npx @lucassantana/sharekit install
```

*Visual:* Code diff mockup: constitution.json changed, CI gate passes. Same GIF treatment.

*Targeting:* same subreddits; A/B split 50/50 across placements. Measure CTR + comment quality (A2: "how does the gate work?" is a win; "nice skills" is a loss).

---

### X/Twitter Ads

**Thread format (promote organic win)**

*Lead tweet:*
```
Your Claude Code agent has no constitution.

If your routing changes tomorrow, you won't know it broke until a user hits it.

Here's what we wire into CI to catch agent-behavior regressions: same rigor your test suite gives code.

[embed demo clip]
```

*Replies (thread continuation):*
1. "The eval gate runs 40 frozen tasks, catches >5pp accuracy drop on config changes, and blocks merge if policy drifted."
2. "Constitution in git means: diffs are readable, governance is auditable, security is versioned."
3. "Install in 5 minutes: `npx @lucassantana/sharekit install`. Opens an issue if you hit a gate, that's a real problem we want to know about."

*Targeting:* Followers of: Anthropic, OpenCode, @agentic_dev, @agentops, @langgraph; exclude retweet-heavy accounts (reduce noise).

*Metric:* link clicks to sharekit landing page, NOT likes or retweets. Gate continues or pause based on CTR vs X average (dev-tool content typically 0.3-0.5% CTR; target 0.5%+).

---

### Newsletter Sponsorships

**Sponsor slot template (for TLDR AI, Pointer, The Batch rotation)**

*Slot format:* 2-3 lines, written as editor's note (not banner).

```
This week's governance thing:

sharekit is a CI gate that catches agent-behavior regressions: same way your test suite catches code bugs. 
Constitution in git. Eval gates in CI. Install: npx @lucassantana/sharekit install
```

*Targeting:* Rotate across 3 newsletters (3-week cycle, 1 send per newsletter):
- TLDR AI (600k subscribers, $500-800/send): broadest audience, best reach
- Pointer (40k highly technical, $300-400/send): highest dev intent
- The Batch (highest open rate for AI content, ~$600/send)

*Timing:* Begin test tier only after G3 passes (activation confirmed). One send/week during test phase (weeks 3-6); measure CTR + install rate difference vs Reddit over same window.

---

### Google Ads

**Campaign structure (capture-net only)**

*Ad groups:*
1. "Governance keywords": `claude code config`, `claude code hooks`, `opencode configuration` (3 keywords)
2. "Security keywords": `agent security`, `claude code security` (2 keywords)
3. "Long-tail config": broad match on `how to configure`, `how to set up` + `claude code` or `opencode` (4 keyword combos)

*Ads (text-only, landing page = README with "Install" CTA prominent):*

```
Variant 1: "Stop agent drift"
Headline 1: Stop agent behavior drift before it hits prod
Headline 2: CI gates for Claude Code & OpenCode governance
Headline 3: Install in 5 minutes

Description: Your agent has no constitution. sharekit wires in eval gates that catch routing regressions, secret leaks, and policy drift, right in CI.
```

```
Variant 2: "Agent governance"
Headline 1: Governance-as-code for your Claude Code agent
Headline 2: Audit, gate, and enforce agent behavior in CI
Headline 3: npx @lucassantana/sharekit install

Description: Constitution in git, eval gates in CI. Same rigor you give your code tests, now for agent behavior.
```

*Budget:* $30-50/month during test tier (Q3 2026). Pause if CTR <0.5% for 2 consecutive weeks; reallocate to Reddit.

*Tracking:* UTM `source=google_ads&medium=cpc&campaign=sharekit_test_tier`.

---

## Budget Allocation

### Test Tier ($200/month for weeks 3-6 post-launch, conditional on G1-G5 pass + 2+ organic channels)

| Channel | Allocation | Weekly spend | Purpose |
|---------|------------|--------------|---------|
| Reddit (r/ClaudeAI + r/ChatGPTCoding) | $100 | $25 | Primary demand test; 2 ad variants (A/B) |
| X/Twitter (followers targeting) | $50 | $12.50 | Secondary reach; promote organic thread |
| Google Ads (long-tail keywords) | $30 | $7.50 | Capture net; expect <5 clicks/week |
| Reserve | $20 | $5 | Holdback for pausing underperforming variant |

**Measurement window:** 4 weeks. Success = cost per engaged inbound (issue/discussion from new install) < $50 during test tier; if true, proceed to scale tier. Failure = all inbound is star-only vanity for 2+ consecutive weeks; pivot to organic-only.

### Scale Tier ($1,000/month, unlocked only if test tier hits CAC target)

| Channel | Allocation | Rationale |
|---------|------------|-----------|
| Reddit (scaled 2x) | $400 | Highest CTR + install conversion; increase ad frequency |
| Newsletter sponsorships (rotation) | $250 | 2-3 sends/month; highest-intent inbound |
| X/Twitter (scaled 2x) | $200 | Expand targeting to agent-tooling ecosystem followers |
| Google Ads (scaled) | $100 | Increase bid for top keywords; expand negative keywords based on test learnings |
| Reserve | $50 | Test creative variants, pause leakers |

**Timeline:** Unlocked only if test tier runs 4+ weeks AND cost per engaged install < $25 (signaling strong positioning match). If CAC > $25 after 4 weeks, extend test tier 2 more weeks before decision; if still high, stop paid spend entirely.

---

## Creative Guardrails (aligned to sharekit positioning)

### DO

- Lead with **governance**, **auditable**, **gates**, **CI**, **constitution**
- Show agent behavior regression catching eval gates (visual)
- Reference installed user count sparsely; focus on early adopter credibility ("10+ devs")
- Emphasize your team's control: "you audit it, you diff it, you gate it"
- Use developer-native tone (no corporate voice)

### DON'T

- Say "autonomous agent harness" (scary for enterprises; ruflo owns orchestration)
- Lead with "49 skills / 55 agents / 78 hooks" (skill catalog comparison = losing battle)
- Claim superiority over specific competitors (loses positioning fight; position on unique slice, not head-to-head)
- Use "AI teammate" framing here (reserved for marketing layer; ads are GTM, stay tactical)
- Create Instagram-style visuals or video (text + screenshots for dev audiences)

---

## Measurement & Kill Criteria

### Success metrics (per launch-plan G2, G3, G5)

- **G2 Demand**: 5+ issues/discussions from non-authors referencing *how* the product works (not "cool repo")
- **G3 Activation**: 3+ users reference hooks/gates firing in their setup
- **G5 Retention proxy**: 2+ users open a second issue/PR/config question

**Ads success**: same metrics, attributed to ad source via UTM + Google Analytics. Ad spend is profitable if cost per engaged inbound (user who opens an issue or asks a config question) stays < $50 test tier (same bar as the Test Tier success criteria above), < $20 scale tier.

### Pausing rules (stop all spend if any of these trigger)

1. **Vanity metric failure** (2+ consecutive weeks): paid inbound is stars only; zero issues, zero config questions from paid users → reallocate to organic.
2. **CAC explosion** (test tier after 4 weeks): cost per engaged inbound > $50; extend test 2 more weeks or kill.
3. **Positioning miss**: inbound consistently says "cool skill collection" unprompted; messaging didn't land → iterate creative once, then stop if still flat.
4. **Harness compatibility issue** (unplanned): upstream Claude Code or OpenCode release breaks installs at scale; pause spend until compat resolved (otherwise ads drive installs that fail, generating negative sentiment).

---

## Creative Assets Needed (pre-launch checklist)

Before test tier begins, have ready:

- [ ] Demo GIF: eval gate catching routing regression in CI (2 sec, ~5MB max for Reddit)
- [ ] Constitution.json diff screenshot (code, light theme, contrasting pass/fail badges)
- [ ] One Show HN post draft (Day 1 of launch week)
- [ ] Three landing-page variants for Google Ads (link to README section per variant)
- [ ] 2 Reddit ad creative variants (copy + GIF)
- [ ] 1 X thread template (5 tweets, linked GIFs)
- [ ] Newsletter sponsor copy template (2 versions: governance angle + compliance angle)

---

## Approval Gate

**This plan is NOT LIVE.** Before any spend:

1. **G1-G5 gates MUST pass** (per launch-plan section 3). Zero exceptions.
2. **2+ organic channels confirmed producing repeatable inbound** (launch-plan section 4 trigger).
3. **Operator explicit approval**: "yes, start test tier" in an issue or message.
4. **Harness compat verified**: Claude Code and OpenCode versions wired at launch are confirmed stable.

Do not spend budget until all four conditions are met.

---

## Session notes

**Meta (Facebook/Instagram) assessment:**

Requested but not recommended. Meta's algorithm and audience targeting are misaligned with developer-tool positioning (governance/security/auditability). No incumbent dev-tool succeeds on Meta as primary channel. CPM is lower but conversion to engaged inbound is worse. Recommend: reject outright and allocate budget to Reddit + newsletter rotation (2x higher intent per dollar).

**Positioning reinforcement:**

These ads are written to win on the "governance" angle, not the "skill collection" angle. If early organic signal contradicts this (community says "love the skills repo" unprompted), iterate positioning first before scaling spend. Ads amplify what's working; they don't fix what's broken.

**Solo maintainer reality:**

All measurement, creative iteration, and pause/go decisions here fall to one person until contributors appear. Scale only as much as you can respond to in <48h.

---

Last updated: 2026-08-05. Next review: when G1-G5 pass, or if organic channels show signal drift.
