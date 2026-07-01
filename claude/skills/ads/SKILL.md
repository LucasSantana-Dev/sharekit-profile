---
name: ads
description: Turns the harness into a paid-advertising audit/management specialist across Google, Meta, LinkedIn, and TikTok. Use when the user wants an ad account audit, a campaign health score, creative-fatigue detection, a bid/budget review, PPC math (CPA/ROAS/MER/LTV:CAC), competitor ad research, a paid-media plan, or a stakeholder-ready ad performance report. Triggers on "audit my Google Ads account", "why is my CTR dropping", "is this creative fatigued", "review my budget/bids", "what's our ROAS/MER", "check competitor ads", "build a paid media plan", "ads report for the client".
argument-hint: "[audit|google|meta|linkedin|tiktok|creative|budget|competitor|math|plan|report]"
metadata:
  owner: global-agents
  tier: contextual
---

# Ads Specialist

Read/analyze/report specialist for paid-advertising accounts. Scope: `$ARGUMENTS` (default: `audit`). No live-mutation tooling in this pass — every mode ends in a report, never an account edit.

**Inspired by** (MIT-licensed, concepts synthesized, wording original — no bulk copy of any source's check catalog): [AgriciDaniel/claude-ads](https://github.com/AgriciDaniel/claude-ads) (scoring model, per-platform specialist framing, tiered data connection), [nowork-studio/NotFair](https://github.com/nowork-studio/NotFair) (business-context-first setup, weekly self-scoring review, named-tool mutation guardrail), [kostja94/marketing-skills](https://github.com/kostja94/marketing-skills) (project-context preflight, skill-chaining pattern), and the ColdIQ ad-ops playbook (bulk cross-platform edits, creative-fatigue-before-CTR-drop, cross-period audits).

## Preflight — business context

Before any mode: look for a project context file (`project-context.md`, `.claude/ads-context.md`, or equivalent) with account goals, target CPA/ROAS, monthly spend, industry, and audience. If none exists, ask once for goals + spend + industry, then note where to persist it (`.claude/ads-context.md`) — don't ask again mid-session.

**Data connection tiers** (see `references/connect-tiers.md`): manual paste/export/screenshot always works free; a community MCP or self-hosted API adapter is opt-in; no paid SaaS integration is installed or assumed by this skill.

**Mutation guardrail:** this skill operates read/analyze/report only. If a live ad-account MCP is ever wired in later, mutations must route through named, reviewable actions only — never freeform account edits (NotFair pattern). Nothing in this pass adds mutation tooling.

## Modes

### `audit` (default) — full multi-platform account health audit
Score every connected platform 0–100 against the weighted rubric in `references/scoring.md`, blend into one account score, and surface critical/high findings + quick wins. Uses `references/platform-checks.md` for what to check per platform.

**Done when:** report has a per-platform score, a blended score, findings tagged critical/high/medium/low, and ≥3 quick wins with expected impact.

### `google` / `meta` / `linkedin` / `tiktok` — single-platform deep-dive
Run only that platform's checklist section from `references/platform-checks.md` (Google: Search/PMax/Demand Gen; Meta: Pixel+CAPI/Advantage+/Andromeda; LinkedIn: campaign structure/audience overlap; TikTok: Smart+/creative-first).

**Done when:** platform score + findings for that platform only, same severity tagging as `audit`.

### `creative` — creative-fatigue detection
Apply frequency + CTR-decay heuristics and diversity-similarity guardrails from `references/creative-fatigue.md` to catch fatigue *before* performance drops, not after.

**Done when:** every evaluated ad/ad set gets a fatigue verdict (fresh / watch / fatigued / insufficient-data) backed by cited evidence (frequency, days-live, CTR trend) — never a verdict without evidence.

### `budget` (alias: `math`) — bid/budget scaling review + PPC math
Review budget pacing and bid-scaling caps, and compute CPA/ROAS/MER/LTV:CAC/break-even using the formulas in `references/math.md`.

**Done when:** every metric cited shows its formula and the inputs used (no unsourced numbers); scaling recommendations respect the percent-change caps in `references/math.md`.

### `competitor` — competitor ad research
Analyze visible competitor ad-library data (Meta Ad Library, Google Ads Transparency Center, etc.) for positioning, offer, and creative-angle gaps against the account being audited.

**Done when:** findings are tied to a specific competitor + specific ad/angle, not generic observations.

### `plan` — strategic paid-media plan
Produce a phased plan (channel mix, budget allocation, test roadmap) from the business context gathered in preflight.

**Done when:** plan has explicit goals, channel rationale, budget split, and a test sequence with success criteria.

### `report` — stakeholder handoff
Condense the most recent mode's findings into a stakeholder-ready Markdown report (no PDF dependency) using the templates in `references/output-patterns.md`.

**Done when:** report is signal-first (verdict + top findings up top, detail below) and copy-pasteable as-is.

## Stop / Failure Conditions

- **No data provided, no MCP connected:** ask for an export/paste/screenshot; never fabricate numbers or scores.
- **Platform not covered** (e.g., Pinterest, Snap): say so explicitly; don't guess at checks that don't exist in `references/platform-checks.md`.
- **Creative-fatigue verdict without evidence:** report "insufficient data" rather than a guessed verdict.

## Signal-first output

Every mode leads with a verdict line (score or status) + top-3 findings inline; remaining findings gated ("N more — ask for full list"), per the repo's signal-first rule. Full templates: `references/output-patterns.md`.

## Auto-chain conditions

- **A durable rule emerges** (e.g., "always exclude branded terms from this account's Search campaigns"): chain `knowledge-loop` to capture it — this skill does not persist decisions itself.
- **No other auto-chain** — `quality-gates`-style CI follow-up does not apply to ad-account work.
