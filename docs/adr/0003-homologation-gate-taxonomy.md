# ADR 0003: Homologation Gate Taxonomy — reference exemplars, not a template

**Status:** Accepted
**Created:** 2026-07-25
**Owner:** Lucas Santana
**Tags:** sharekit-profile, autonomy-tiers, compliance, homologation, release-gating

## Context

A user request ("work profile on sharekit covering compliance, homologation, teamwork,
limited scope, card/prototype fidelity") triggered a 5-lens, 2-round debate (`/deep-research`
+ `/debate`, 2026-07-25). One thread of that debate: Lucas already has four real,
already-shipped "homologation" patterns (Brazilian-PT term for a staging/UAT sign-off gate
before prod) living as separate per-project memory notes, never abstracted:

1. **Lucky** — PR labeled `staging` auto-deploys to a shared staging environment before prod.
2. **Criativaria admin-panel** — merge-to-main = prod; D1 migrations auto-apply on merge.
3. **calculadora** — real incident: Cloudflare Pages secrets bind at DEPLOY time, not build
   time, which broke a staging-gate flag-flip (caught only because staging existed as a
   distinct step from prod).
4. **homelab** — release-cut process: squash `chore/release-*` → main, resolve bot review
   threads, tag, cherry-pick reconcile → release branch.

The homologation-lens (Round 1) argued these four share a *conceptual* gate ("what blocks a
commit from reaching production?") but incompatible *implementations* (label-routing vs.
merge-is-prod vs. deploy-time secret binding vs. branch-promotion) — forcing them into one
scaffolded template would require a configuration abstraction (gate_type, review_signal,
deploy_target) that adds a layer without removing any of the per-project specificity. The
debate's Round 2 synthesis (converged across all 4 debating lenses) additionally rejected
shipping this as a **distributed file scaffolded into target repos** — that repeats
ADR-0039's already-rejected two-channel drift risk and doesn't survive the "Lucas is often a
guest contributor on Thoughtworks client repos" case cleanly. The debate's overall
convergence: augment *existing wired mechanisms* (hooks, agents, gate logic) rather than
create new distributed content, and treat cross-project patterns as reference documentation
in the canonical profile, not per-repo scaffolds.

## Decision

**Publish a taxonomy of the four real gate patterns as reference exemplars in
`sharekit-profile/docs/adr/`, not as a prescriptive template or a second profile/SKU.**

1. This document names the four patterns and the one question each answers: *what
   mechanism decides a commit isn't ready for prod yet?*
   - **Label-routing** (Lucky): a PR label (`staging`) is the review/promotion signal; CI
     reads the label to pick a deploy target.
   - **Merge-is-prod** (Criativaria): there is no separate staging environment; merge to
     `main` is the promotion event, so all gating has to happen pre-merge (PR review,
     migration-safety checks) since there's no post-merge undo step.
   - **Deploy-time binding** (calculadora): secrets/config bind at deploy time, not build
     time — the gate isn't a branch or label at all, it's *when in the pipeline* a config
     value gets read, and testing that against a build-time assumption silently passes
     while staging fails.
   - **Branch-promotion** (homelab): a long-lived `release` branch accumulates commits,
     gets squash-reconciled against `main`, tagged, then cherry-picked back — the gate is a
     branch hierarchy + manual reconciliation step, not a single merge event.
2. **No new template, no `.claude/homologation.md` stub, no `sharekit-cli init --profile`
   flag for now.** A future project picks the pattern (or a variant) that matches its own
   deploy topology by reading this taxonomy, not by filling in a generic form — the debate's
   evidence (four real projects, four incompatible mechanisms) says a generic form would
   either be too vague to action or too narrow to fit a fifth project. The `init --profile
   work` flag specifically is deferred, not rejected outright — see Revisit when.
3. If a fifth genuinely-distinct gate mechanism appears in a future project, add it here as
   a fifth exemplar rather than generalizing the existing four into an abstraction — per
   the Alternatives section below, premature abstraction was explicitly rejected once
   already (ADR-0039's own generate-from-allowlist alternative, rejected "until hand-curation
   exceeds ~150 skills"; same reasoning: don't build the generator before the demand for
   variation is proven).

## Alternatives considered

- **Build a configurable `.claude/homologation.md` template** (gate_type, review_signal,
  deploy_target fields), scaffolded via `sharekit-cli init`: rejected for now, not
  permanently (see Revisit when) — the four real patterns don't share enough mechanism to
  make the fields meaningful today (a `deploy_target`
  field means nothing for calculadora's deploy-time-binding gate, which isn't about *where*
  but *when*). Would produce a form most future projects fill in wrong or ignore.
- **Second `sharekit-profile-work` distribution channel**: rejected — this is the same
  two-channel drift ADR-0039 already burned Lucas on (skills silently missing from the
  public profile for a stretch). Unanimous rejection across all 5 debate lenses, both
  rounds.
- **Do nothing** (leave the four patterns as separate per-project memory notes): rejected —
  the whole point of a debate-driven initiative was that this pattern-recognition is
  genuinely useful cross-project reference material; not writing it down loses it to
  memory decay even though building a template around it would be premature abstraction.

## Consequences

- Positive: zero new maintenance surface (a markdown doc, not a template or generator);
  the four exemplars stay individually correct and specific instead of being flattened into
  a lossy shared schema; consistent with ADR-0039's single-canonical-distribution decision.
- Negative: no automation — a future project still has to manually read this doc and pick a
  pattern; there's no `init` flag that "does homologation for you."
- Neutral: this document lives in `sharekit-profile/docs/adr/`, which is source-controlled
  but not part of the curated public skill/agent/hook/standard sync (`curated-skills.txt`
  scope) — it's operator reference material, not something `npx @lucassantana/sharekit
  install` ships to other users. If demand ever surfaces for sharing this taxonomy publicly,
  that's a separate curation decision, not implied by writing it here.

## Revisit when

- A fifth genuinely-distinct gate mechanism appears in a new project → add it as a fifth
  exemplar, don't retrofit an abstraction.
- 3+ future projects independently ask "which of these patterns should I use" and the answer
  is unclear from reading this doc alone → that's evidence a decision-tree/checklist format
  would help more than free-text exemplars; revisit format, not scope.
- Someone other than Lucas asks to reuse this taxonomy → separate curation decision on
  whether it belongs in the public `sharekit-profile` install surface.
- Lucas gets write access on a real client engagement and a teammate needs a starter doc →
  revisit the `sharekit-cli init --profile work` flag (architecture lens's Round 1 proposal,
  deferred not rejected), gated behind an explicit flag, not shipped as a default.
