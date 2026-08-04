# sharekit-profile — GTM Launch Plan

Date: 2026-08-04. Status: pre-launch (1 star, 0 forks, no distribution).
Frameworks: gtm-positioning-strategy (Crawl-Walk-Run, word-choice, defensibility), gtm-0-to-1-launch (three-layer diagnosis, first-10-customers, 2-week experiment cycle).

## 1. Positioning

### One-sentence pitch

sharekit is the governed agent profile — a portable, auditable configuration layer for Claude Code and OpenCode that enforces how your AI agents behave, with security hooks and behavioral eval gates wired into CI.

### Category: profile, not framework

The market already has frameworks: spec-kit (125k stars), BMAD-METHOD (51.5k), ruflo (67k), SuperClaude (23.6k). Every one of them sells "a system for how you build." sharekit is not that. It is a **profile**: the governed config layer you install on top of whatever workflow you already run — "home-manager for agent config." You keep your framework; sharekit keeps the agent honest.

This category framing is structural: a framework competes head-on with 9 incumbents. A profile is orthogonal to all of them — it can be the governance layer for a BMAD user just as well as for a spec-kit user.

### The word-change insight (per positioning skill)

The positioning skill's core lesson: "autonomous" scared enterprises; "AI teammate" closed deals. Same product, different framing. For sharekit the equivalent trap is **"catalog" vs "profile"** — and **"controls" vs "governance"**:

- Never lead with "49 skills / 49 hooks / 50 agents." "Catalog" sounds like davila7/claude-code-templates (30.1k) — a losing comparison, and it invites "I can get skills elsewhere" as the takeaway.
- Lead with **"enforce"**, **"auditable"**, **"gates"**. The buyer psychology being reassured is "my agent won't leak secrets / drift from policy / silently degrade" — not "I get more stuff."
- Use "you stay in control" language: the constitution, threat model, and MCP default-deny policy are artifacts *your team* can read, diff, and gate in CI. The agent augments; the constitution constrains.

### What we don't say

- Not "autonomous agent harness" (scary, plus ruflo owns orchestration).
- Not "skills marketplace" (wshobson/agents owns it, 38.5k stars).
- Not "spec-driven" (spec-kit owns it, 125k stars).
- No competitor-name comparisons on the homepage (defensive positioning).

### The wedge: governance-as-code is an empty slice

Verified 2026-08-04: no incumbent enforces agent behavior. Agent OS v3 — the closest "standards-first" competitor (5.2k stars) — explicitly went advisory-only. The slice "governance-as-code + behavioral eval gates" has zero occupants. That is a **market-position claim** (level 2 on the defensibility hierarchy): own it first, and copycats look derivative. It is credible now, not roadmap:

1. **Governance-as-code** — `.harness/constitution.json` + human-readable mirror, committed threat model, MCP deny-by-default policy. Auditable, diffable, enforceable.
2. **Behavioral eval gates** — routing-eval gate fails CI on >5pp accuracy regression on config changes. Nobody else gates agent *behavior*; everyone else gates code.
3. **Harness-portable** — Claude Code + OpenCode, with a drift detector keeping the two views identical. Portability is also the moat against harness lock-in churn.
4. **Security-first hooks** — gitleaks, dangerous-pattern, prompt-injection scanners in the hook chain. This is the team/compliance story.

### Crawl-Walk-Run rollout (per positioning skill methodology)

**Crawl (weeks 1–2) — validate messaging before committing:**

- Two README/tagline variants tested in the wild, not by internal consensus:
  - A: "The governed profile for Claude Code and OpenCode" (governance angle)
  - B: "Agent config you can audit, gate, and enforce in CI" (compliance/CI angle)
- Show HN title doubles as the A/B: post once with A; gauge comment uptake on the governance claim vs the skills claim.
- Direct messages to ~15 Claude Code power users (from r/ClaudeAI, Discord, X replies to Anthropic posts): pitch variant A to half, B to half. Measure reply quality: "how does the eval gate work?" is a win signal; "cool collection" is a loss signal.
- Go/No-Go: one variant generates measurably better engagement (replies asking about governance/eval, not skills count). If both variants get "nice skills repo," the positioning failed — fix messaging, not product.

**Walk (weeks 3–4) — align everything to the winner:**

- Rewrite README lead, repo description, awesome-list PR blurb, and docs to the winning angle.
- Produce one canonical demo artifact: a 60-second clip of `npx @lucassantana/sharekit install` → agent blocked by constitution → eval gate catching a routing regression in CI.
- Write the one "undeniable use case" doc: "Stop your agent from leaking secrets and drifting from policy — in one install." Restrict the README's first screen to that use case, not the 49-skill inventory.

**Run (week 5+, only if gates pass) — scale:**

- Per-surface landing copy (awesome list, marketplace listings, blog post "Why agent config needs governance-as-code").
- Partner-led entry per the skill: approach the awesome-claude-code maintainer and OpenCode community as distribution partners — their users need governance, and we approach with their users' problem, not our pitch.

## 2. 0-to-1 Launch Playbook

### Press ≠ growth — internalized warning

The skill's canonical failure: 50K impressions, 12 signups, 2 conversions. A sharekit Show HN that trends and yields 200 stars but zero installs, zero issues, zero eval-gate adopters is a vanity event, not growth. The launch goal is not stars — it is **10 users who install, hit a hook or gate, and come back to complain or praise in an issue**. Stars are a leading indicator; issues and install-derived questions are the demand signal.

### Three-layer distribution

- **Layer 1 — Owned**: repo README (rewritten per Walk phase), docs/, the demo clip. Must convert a visitor to `npx` install in <10 minutes (self-serve ready, per the skill's decision tree — otherwise direct outreach only).
- **Layer 2 — Community/direct (primary)**: r/ClaudeAI, Claude Code Discord, OpenCode community, X replies where agent-config pain is visible. Direct outreach per the First-10 framework: ceiling-moment targeting — people who already maintain hand-rolled `.claude/` setups and have hit the ceiling of unversioned, unenforced config. Pitch: "You've built this by hand; sharekit gives you the same thing with a constitution, drift detection, and a CI gate." These convert 3–5x better than cold.
- **Layer 3 — Curated lists (the real competition)**: awesome-claude-code (51.6k stars) PR, wshobson/agents marketplace presence, OpenCode plugin/config listings. One placement here outperforms 10 social posts for durable inbound.

### Launch week plan

- **Day 1 (Tue/Wed)**: Show HN. Title = winning Crawl variant. First comment: the one-paragraph governance-as-code thesis + the demo clip link. Stay in comments all day; the comment quality is the A/B readout.
- **Day 2**: r/ClaudeAI post (self-promo-friendly flair, lead with the eval-gate demo, not the catalog). Cross-post to OpenCode Discord.
- **Day 3**: awesome-claude-code PR submitted. Blurb in governance language, one line, no emoji.
- **Day 4**: X thread — "Your Claude Code agent has no constitution. Here's what that costs (secrets, drift, silent regressions) and how we gate it." LinkedIn mirror for the team/compliance audience.
- **Day 5–7**: Triage everything into the validation ledger (section 3). Reply to every comment/issue within 12h — early adopters measure maintainer responsiveness.

### Early-adopter profile

1. **Power users** running Claude Code or OpenCode daily who already hand-maintain `.claude/` or `.opencode/` config — the ceiling-moment segment. Found in r/ClaudeAI, Discord, X.
2. **Security-conscious teams** (2–10 devs) adopting agentic coding who need an auditable answer to "what is the agent allowed to do?" — the governance/eval story is written for them. Found via LinkedIn and direct outreach to platform/DevEx leads.
3. Not: casual users wanting a skill grab-bag. If they arrive anyway, fine — but no messaging is optimized for them.

## 3. Validation Gates

Demand for this exact artifact is unproven (1 star). Cheap validation precedes any heavy investment. All metrics from week 0 = launch day.

| Gate | Window | Metric | Pass | Fail |
|------|--------|--------|------|------|
| G1 Attention | Week 1 | Show HN + Reddit + X combined | 100+ stars OR 300+ upvotes/points total | <30 stars, flat comments |
| G2 Demand | Weeks 1–2 | Inbound that implies *use* | 5+ issues/discussions from non-authors (install errors, porting asks, gate questions) | Only stars, zero usage signal |
| G3 Activation | Weeks 2–3 | Install-to-engagement | 3+ users reference hooks/gates firing in their setup | Installs invisible (no signal at all) |
| G4 Positioning | Weeks 2–4 | Message-market fit | Inbound mentions governance/eval/security unprompted | Inbound says "nice skill collection" |
| G5 Retention proxy | Week 4 | Return behavior | 2+ users open a second issue / PR / config question | All engagement is one-shot drive-by |

Decisions:

- **All pass** → proceed to Run phase + ads test tier (section 4). Allocate 3x effort per the 2-week experiment cycle.
- **G1+G2 pass, G3–G5 fail** → Layer 2 (experience) problem per the three-layer diagnosis: install or first-run is broken. Fix onboarding, re-gate in 2 weeks. No marketing spend.
- **G1 passes, G2 fails** → Layer 1 (positioning) problem: attention without demand. Iterate messaging once, re-run Crawl. If second iteration also fails → pivot the artifact (sell the eval gate standalone, or fold into OpenCode ecosystem) or kill.
- **G1 fails** → distribution problem, not product. Do NOT iterate the product; iterate channels (newsletter sponsorships, OpenCode community first). One retry with a different surface, then kill if flat again.

Kill/pivot criteria are written down now to avoid sunk-cost drift later: **by end of week 4, if fewer than 5 non-author users have demonstrably used the product, stop investing beyond maintenance mode.**

## 4. Ads Plan (Phase 3 — only after organic validation)

No paid spend before G1–G5 pass. Ads amplify validated demand; they cannot manufacture it, and dev audiences punish paid promotion of unvalidated tools.

### Channels (ranked by fit)

1. **Reddit ads** on r/ClaudeAI + r/ChatGPTCoding — most targeted to actual Claude Code users; promoted posts blend in if copy reads like a dev, not a marketer. Rough: CPM $5–15, CPC $0.50–1.50 for dev-tool creative.
2. **X/Twitter ads** — promote the winning organic thread to followers of Anthropic-adjacent and agent-tooling accounts. Rough: CPM $5–10, CPC $0.50–2.00; engagement quality varies, gate on link clicks not likes.
3. **Newsletter/listing sponsorships** — TLDR AI and similar dev newsletters; sponsored placement in agentic-coding newsletters. Rough: $300–1,500 per send for mid-tier dev newsletters; best click quality per dollar in this category.
4. **Google Ads** — low volume but high intent on "claude code config", "claude code hooks", "claude code skills", "opencode config". Long-tail dev keywords: rough CPC $1–3, tiny volumes; use as a capture net, not a growth engine.
5. Not planned: Product Hunt promoted placement, broad LinkedIn ads (CPC $5–10+ and poor dev intent).

### Budget tiers

| Tier | Monthly | Use when | Mix |
|------|---------|----------|-----|
| $0 organic-only | $0 | Default state; pre-G5 and anytime paid tests underperform | Community posts, awesome-list, direct outreach |
| $200 test | $200 | G1–G5 passed, first 90 days post-launch | $100 Reddit + $50 X + $50 Google long-tail; 2 ad variants = the paid extension of Crawl |
| $1k scale | $1,000 | Paid test tier shows signup/install CAC that converts to G2-style inbound at better rate than equivalent organic effort | $400 Reddit, $250 newsletter sponsorship rotation, $200 X, $150 Google |

### Trigger conditions for spend

- **Start test tier**: G1–G5 all pass AND 2+ organic channels are producing repeatable inbound (so ad creative can copy proven messaging).
- **Start scale tier**: test tier runs 4+ weeks AND cost per engaged inbound (issue/discussion from a real install) is under $25.
- **Stop all spend**: any month where paid inbound is star-only vanity (no issues, no questions) for 2 consecutive weeks, or organic channels outperform paid on engaged inbound per unit effort.

Measurement discipline: ads are judged on the same G-metrics as organic (issues, gate questions, second-visit behavior), never on impressions or raw stars.

## 5. Maintenance-Tail Honesty

Adopting users means adopting obligations. Before scaling, accept what this product commits to:

- **Harness version compat**: Claude Code and OpenCode ship frequently; settings schema, hook API, and skill format changes can break installs. Each upstream release needs a compat check — this is a standing weekly chore, and the drift detector only helps if run. Expect compat issues to dominate the issue tracker.
- **Porting pressure**: users will ask for Cursor, Codex CLI, Gemini, Windsurf ports. Each port multiplies the drift-detection and compat surface. Default answer for the first 6 months: "no" — portability across two harnesses is the differentiator; five is a support sinkhole. Revisit only if G-metrics pass and a port request repeats from 5+ distinct users.
- **Governance artifact stewardship**: constitution, threat model, and MCP policy are the product's credibility. They must stay current and honest — a stale threat model in a security-positioned repo is worse than none.
- **Eval gate maintenance**: the 40-task routing baseline and pinned model will rot (model deprecations, task drift). Budget upkeep time or the flagship differentiator silently degrades.
- **Issue responsiveness**: 10 early adopters forgiving slow features will not forgive ignored issues. Target <48h first response while user count is small.
- **Solo-maintainer reality**: all of the above lands on one person until contributors appear. Scope growth to what is answerable; a smaller, impeccably maintained profile beats a sprawling, stale one — and staleness directly contradicts the "governance you can trust" pitch.

## Appendix: What we are explicitly not doing

- Not competing as a skills catalog (losing battle vs wshobson/agents, claude-code-templates).
- Not pursuing press/blog coverage in the 0-to-1 phase (press ≠ growth).
- Not building framework features (spec workflows, orchestration) to chase incumbents.
- Not spending on ads before G1–G5 pass.
- Not porting to additional harnesses in the first 6 months.
