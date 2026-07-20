---
name: app-teardown
description: Reverse-engineer a live application (web app, SaaS, mobile) by walking its real flows in the browser and map every idea worth taking — UX patterns, features, visual design, copy, growth mechanics — into a teardown report where each finding carries evidence, an adopt/adapt/already-have/reject verdict, and a constraint rationale for our context. Use when asked "faz um teardown do app X", "analisa esse app e mapeia ideias", "what can we steal from X", "reverse-engineer this product", "competitive teardown", "o que dá pra aproveitar do app Y". For a codebase or repository use code-teardown; for purely visual reference boards from design platforms use frontend-reference-hunt.
triggers:
  - teardown do app
  - analisa esse app e mapeia ideias
  - what can we steal from
  - reverse-engineer this product
  - competitive teardown
  - o que dá pra aproveitar desse app
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/app-teardown
---

# App Teardown

Studies a live product the way a chef eats at a rival's restaurant: walk the real flows,
name what works, explain WHY it works for them, and decide what transfers to our context.
The output is a decision artifact, not a tour.

## Use When

- A live app/product should be mined for ideas applicable to one of our projects.
- Before building a surface that a named competitor/product already does well.
- User names a product and asks what to learn, steal, or adapt from it.

## Do Not Use When

- Target is a repo/codebase → `code-teardown`.
- Only visual direction is wanted (moodboard, type, palette) → `frontend-reference-hunt`.
- Understanding OUR OWN system's internals → `doc-and-modernize`.

## Inputs / Prereqs

- Target URL + whether login is needed (drive the user's Chrome via `claude-in-chrome`).
- OUR context lock: which project the ideas land in, its goals and constraints.
- Memory state-check FIRST: `reference_<target>_evaluated_*` note exists → surface prior
  outcome and stop unless the revisit condition is met.

## Workflow

1. **Scope + constraint capture** — target, key flows to walk, and the gate question:
   why does their design work FOR THEM (scale, audience, pricing model, compliance,
   platform, legacy)? Record it; it powers the cargo-cult gate later.
2. **Live exploration** (claude-in-chrome) — walk onboarding, core flow, settings, empty
   states, error recovery, upgrade/paywall moments. Screenshot each finding into
   `<project>/.claude/design/refs/`. Note deliberate ABSENCES and simplifications too.
3. **Map by dimension** — UX (interaction, feedback, empty/error states), Features
   (jobs-to-be-done, scope cuts, free-vs-paid line), Visual design (type, spacing,
   components, motion), Copy (tone, terminology), Growth (activation, referral, retention
   hooks). 2+ dimensions minimum; skip dimensions irrelevant to the brief.
4. **State-check per candidate finding** — do WE already have it? Query graphify
   (`graphify query`) when the target project has `graphify-out/`, plus grep/memory.
   Mark hits `already-have` instead of re-proposing them.
5. **Verdict + rationale per finding** — apply the contract in
   [references/teardown-contract.md](references/teardown-contract.md): evidence,
   `adopt | adapt | already-have | reject`, the mandatory constraint rationale
   ("[their constraint] → [applies to us?] → [action]"), effort, landing spot in our repo.
6. **Emit + remember** — report to `<project>/docs/reference/<target>-teardown-<date>.md`
   (committable). Memory note `reference_<target>_evaluated_<date>.md` with outcome +
   revisit condition; an "evaluated → nothing" outcome is a valid, valuable result
   (prevents re-evaluation — megabrain/llmwiki precedent). Summary line:
   "N findings, A adopt, D adapt, H already-have, R rejected".

## Outputs / Evidence

- Teardown report with every finding evidenced by a screenshot taken this session.
- Ranked ADOPT list at top with effort + landing spot.
- Memory note with outcome + revisit condition.

## Failure / Stop Conditions

- Login wall you cannot pass → mark `coverage: partial`, continue on public surface.
- Zero adopt/adapt findings → still emit report + "evaluated → nothing" memory; do not
  invent findings to justify the session.
- Never mark `adopt` without the constraint rationale and the state-check — that is the
  cargo-cult failure mode this skill exists to block.

## Load These Resources

- [references/teardown-contract.md](references/teardown-contract.md) — findings schema,
  verdicts, cargo-cult gates, memory protocol (shared with `code-teardown`).

## Related Skills

- `code-teardown` — same contract, repo targets.
- `frontend-reference-hunt` — visual-only reference boards.
- `plan` / `backlog` — consumers of the ADOPT list.

## Memory Hooks

- Read: `reference_<target>_evaluated_*` before starting (mandatory state-check).
- Write: outcome note per teardown, always — including negative outcomes.
