# Team Rollout Playbook

Run a quarter-long harness adoption: pilot team, adjacent teams, org. Pairs
with `docs/team-onboarding.md` (the individual's first hour): this doc is for
whoever OWNS the rollout.

Evidence notes: the champions model and rollout sequencing are corroborated
practice (GitHub rollout-at-scale docs, vendor-stage case studies). Specific
numbers (percentages, day ranges) are practitioner heuristics, not measured
truths: treat them as starting defaults and adjust with your own telemetry.

## Roles (RACI)

| Role | Allocation | Accountable for |
|------|-----------|-----------------|
| **Rollout lead** | 20-30% of a week, all quarter | Sequencing, unblocking, metrics review, this playbook |
| **Skill captain** | ~10% of a week | The shared skill/hook library: reviews contributions, prunes, versions. Without one, libraries stall at ~3 skills |
| **Champions** (1 per team) | opportunistic | Peer help, prompt sharing, first-line support. Chosen for trust, not title |
| **Team members** |: | Follow `docs/team-onboarding.md`, declare in `operators.json` |

A rollout with no named lead collapses in about three weeks. Name the lead
before anything else.

## 30 / 60 / 90

### Days 1-30: install + starter profile (pilot team)

- Pilot composition: ~25-30 people: 20% champions, 60% representative
  members, 20% skeptics. Skeptics are your early warning system; do not
  exclude them.
- Everyone runs `docs/team-onboarding.md`: marketplace install, operators.json,
  starter profile (3 hooks, 3 skills). Resist adding more.
- Success gate: every pilot member has shipped one real task through
  `plan` → `verify`; identity gate catches zero repeat offenders after week 1.

### Days 31-60: leverage

- Grow the shared library by demand only: one new skill/hook per recurring
  pain, reviewed by the skill captain like a code PR (skills are executable
  supply chain: see `docs/THREAT_MODEL.md`).
- Add the second hook tier (drift checks, checklist gates) to teams that ask.
- Watch CLAUDE.md size: >400 lines warn, >800 lines split. Engagement drops
  when the model skims (gate planned as `hooks/check-config-size.sh`).
- Success gate: skill library growing without captain bottlenecks; zero
  abandoned week-1 hooks.

### Days 61-90: governance + expand

- Turn on the governance tier for the pilot: eval gates, attributionPolicy
  mode decision, llm-policy budgets via your gateway (`docs/gateway-mapping.md`).
- Expand to adjacent teams (similar stacks first), adapting the starter
  profile per team. Specialized teams get tailored profiles, not the pilot's.
- Success gate: second team self-onboards from the docs with <1h of rollout
  lead time per person.

## Metrics: outcomes, not seats

Seat/adoption numbers mislead (acceptance rate can run 4x higher than
production-merge rate). Track:

- **Outcome:** PRs through the harness that merge without revert;
  review-rework rate; defect-escape rate vs pre-harness baseline.
- **Engagement:** week-4 retention of pilot members (still using starter
  skills?), not install counts.
- **Cost:** spend per merged PR, not per seat. Budgets live in
  `.harness/llm-policy.json`, enforced at the gateway.
- **Method:** A/B cohorts where possible (one team with, one without),
  not before/after vibes.

## Week-1 failure modes (kill conditions)

1. **No named rollout lead.** Fix before day 1, not after week 3.
2. **Hook fatigue:** shipping dozens of hooks at once. The starter profile
   exists because this is the most common self-inflicted wound.
3. **CLAUDE.md bloat:** everything-in-one-file context rots engagement.
4. **Deferred security review:** skills/hooks are executable supply chain;
   the skill captain reviews them like third-party PRs from day 1.
5. **Mandate without a paved path:** shadow AI is the default (surveys put
   unapproved-tool usage above half of employees). The sanctioned path must
   be easier than the unsanctioned one, or usage goes underground.
6. **Trust debt:** if the harness "saves 5 minutes and adds 15 of checking,"
   adoption collapses. Keep the starter surface small and reliable; expand
   only what earns trust.

## Anti-patterns

- Forking this profile per team (drift guaranteed): use the marketplace
  channel pin instead (`docs/configuration.md` → Update channels).
- Measuring success by acceptance rate or seat count.
- Rolling the pilot's full config to the org (the pilot is a starter
  profile, not a template to clone blindly).
