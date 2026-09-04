---
name: debate
description: Run structured multi-agent debate on decisions with independent positions, rebuttal, and reconciled synthesis. Three-round format with distinct critical lenses debating alternatives before decision-making. Optionally mixes Claude model tiers with OpenRouter providers when user explicitly requests cross-provider diversity.
triggers:
  - debate
  - multi-agent debate
  - argue alternatives
  - cross-examine options
  - multiple perspectives
  - critique options
metadata:
  owner: global-agents
  tier: ephemeral
  canonical_source: ~/.claude/skills/debate
---

# Debate

## Overview

Turns "get multiple agents debating this" into a deterministic three-round structure —
independent positions, cross-examination, reconciled synthesis — instead of an ad-hoc pile
of parallel opinions that never actually engage each other. Built from a real session where
5 Claude-tier lenses debated a video-editing gap analysis in two rounds and converged
cleanly; this skill is that pattern made repeatable and, optionally, cross-provider.

## Use When

- User explicitly asks for N agents/models to debate, argue, or critique a decision.
- A decision has genuine surface for disagreement (tradeoffs, risk, scope, feasibility) —
  not a factual lookup with one right answer.
- User asks to "include other providers" / "openrouter" / "multiple providers" for real
  cross-model diversity, not just multiple Claude calls.

## Do Not Use When

- The question has no real disagreement surface (single correct factual answer) — use
  `/recall` or a plain research pass instead.
- Only one round of independent opinions is needed with no cross-examination — a plain
  `parallel()` fan-out of critics is enough, this skill's Round 2 is the point of using it.
- The user wants a single adversarial reviewer checking one artifact, not a multi-lens
  debate — use `decision-critic` (artifact-only, no tools) or `critic` instead.

## Workflow

### Phase 0 — Frame the question

Write the **ARTIFACT**: the full context a lens needs to argue from (what's been built,
what evidence exists, what's genuinely uncertain). Debates run on secondhand context —
if the artifact is thin or vague, the debate will be too. Include open questions the user
hasn't resolved; lenses should be allowed to disagree about them.

### Phase 1 — Define lenses (not just "agent 1, 2, 3")

Pick 3 by default (the skill's floor — see Failure/Stop Conditions) unless the user asked
for more or the question genuinely has more than 3 distinct angles worth arguing.
**Genuinely distinct critical angles** on the SAME question. Redundant lenses ("reviewer A"
vs "reviewer B" with no real difference in vantage point) produce fake consensus, not
debate. Common archetypes to draw from — pick the ones that actually apply to the question,
don't always reuse the same five:

- **Feasibility** — can this actually be built/done with the tools at hand?
- **Fidelity/quality** — are we chasing the right target, or should the target itself be questioned?
- **Risk/compliance** — licensing, security, safety, supply-chain, legal exposure.
- **Stakeholder-intent/scope** — what does the actual client/user want, and is that even confirmed?
- **Efficiency/pragmatism** — is continued work worth it, or is this scope creep on a thing
  that should ship now?
- **Cost** — token/time/money cost of each path, not just whether it's possible.

**Default every lens and the synthesis to the inherited session model** — omit `model` in
`agent()` opts, per workflow-authoring's own rule ("only set model when you're highly
confident a different tier fits; when unsure, omit"). Tier-diversifying by default was
measured to cost apex-tier tokens (opus/fable) on routine, non-apex decisions (see
2026-09-04 session: fable synthesis + opus lens on a T1 skill-design fork). Escalate a
*specific* lens or the synthesis to a heavier tier only when that piece independently
clears CLAUDE.md's apex-tier bar — public-facing repo, cross-session architecture,
sprint-level undo cost, post-incident — and say the escalation reason out loud:
- `fable` — reserve for a synthesis reconciling genuinely apex-tier disagreement, not by
  default.
- `opus` — a specific lens doing real creative-judgment or devil's-advocate work, when
  that judgment call itself is high-stakes.
- `haiku` — a narrow, checklist-style lens (compliance/licensing fact-check) where cost
  matters more than depth.

Only add **OpenRouter** models when the user explicitly asked for other providers. See
`scripts/openrouter_call.py` — do not hand-roll the curl calls, it already handles the
failure modes below.

**Cost risk — read before enabling (ADR-0047):** OpenRouter-routed calls get zero
Anthropic prompt-cache benefit, unlike the Claude-tier `agent()` calls in the same round —
every third-party model re-pays the full ARTIFACT token cost with no cache discount, each
time. This is the exact shape of the standing rule "no bulk runs on uncached third-party
providers without explicit user request" (prior incident: four-figure single-day spend).
"User explicitly asked" satisfies that rule's letter; it does not by itself bound the
*cost per round*. Before dispatching an OpenRouter round, say the model count and rough
ARTIFACT size out loud so the user is pricing it in, not just consenting to the category.
Cross-provider mode is a deliberate extra on top of Claude-tier diversity (fable/opus/
sonnet/haiku already gives genuine reasoning diversity), not a fix for insufficient
diversity — don't reach for it by default.

### Phase 2 — Round 1 (independent, blind, parallel)

Run all lenses via `parallel()`, **not sequential agent() calls** — the whole point is
they don't see each other yet. Force a structured schema (verdict, 3-5 key_points, single
priority_recommendation) so Round 2 has something concrete to react to, not prose to
re-summarize. **Restate the required field names in the prompt itself**, not just via the
`schema` opt — a lens that drifts from the schema burns its full 5-retry
`StructuredOutput` cap on zero usable output (measured: 99,652 tokens / 63.8s for one
failed lens in the 2026-09-04 session). One line at the end of every lens prompt: "Respond
with the required fields: verdict, key_points (3-5 items), priority_recommendation."

### Phase 3 — Round 2 (rebuttal, peers visible)

Compile a compact summary of all Round 1 positions (verdict + key_points + priority per
lens — not the full prose, keep this cheap). Send it back to each lens with an explicit
instruction: **engage at least 2 other lenses by name and either rebut or concede** — do
not just restate Round 1. This is the actual debate mechanic; skipping it produces 5
independent opinions, not a debate. Same schema-drift risk as Round 1 — restate the
required field names in the rebuttal prompt too, it is a fresh `agent()` call with its own
retry budget.

### Phase 4 — Synthesis

One agent (default: inherited session model; escalate to `fable` only when the
disagreement being reconciled independently clears the apex-tier bar per Phase 1's
escalation rule) reads every Round 1 + Round 2 position and produces:
1. **Convergence** — where all/most lenses agreed.
2. **Disagreements** — each one named explicitly, with which lens's argument won and why
   (never a silent average; if truly unresolvable, say so and flag it for the user).
3. **Phased plan** — smallest safe next action first, gated on anything still uncertain.

## Outputs / Evidence

```
DEBATE — <question>
  Lenses:        N (<label1 [model1]>, <label2 [model2]>, ...)
  Round 1:       N/N responded
  Round 2:       N/N rebutted (cross-referenced peers: yes/no)
  Convergence:   <bullets>
  Disagreements: <bullet: X vs Y -> resolved for X because ... | flagged for user>
  Plan:          <phased actions, smallest safe first>
  Providers:     Claude only | Claude + OpenRouter (<models used> | <models failed: reason>)
```

## Failure / Stop Conditions

- **Fewer than 3 lenses requested** — not a real debate; recommend a single `critic` or
  `decision-critic` pass instead.
- **No genuine disagreement surface in the question** — surface this instead of forcing
  artificial debate: "this doesn't have real tradeoff surface, recommend plain research."
- **OpenRouter requested but the key is missing, expired, or over its spend/rate limit** —
  surface the exact error (e.g. `403 Key limit exceeded`) and ask whether to proceed
  Claude-only or fix the key first. Never silently drop to Claude-only without saying so.
- **Invalid OpenRouter model slug** — `scripts/openrouter_call.py` validates against the
  live `/models` endpoint first; do not guess slugs from training data, they drift
  (e.g. `google/gemini-3-pro` doesn't exist, `google/gemini-3-pro-image` does).
- **Round 2 lenses just restating Round 1** — the prompt must name specific peers to
  engage; if a lens's Round 2 output doesn't reference at least one peer, it isn't a
  rebuttal, treat it as a Round 1 duplicate and note this in the reconciliation.
- **Synthesis silently averaging instead of deciding** — reject any synthesis that doesn't
  name a winner (or explicit non-resolution) per disagreement.

## Load These Resources

- `references/debate-workflow-template.js` — parametrized `Workflow()` script implementing
  Phases 1-4. Fill in `ARTIFACT`, `LENSES` (with `model` per lens), and optionally
  `OPENROUTER_MODELS`, then invoke via the `Workflow` tool.
- `scripts/openrouter_call.py` — Keychain retrieval (`OPENROUTER_API_KEY` service name) +
  live model-slug validation + parallel dispatch + per-model error surfacing for
  cross-provider rounds. Callable standalone or from the workflow template.

## Memory Hooks

Ephemeral — no default memory reads/writes. If the synthesis reaches a durable decision
worth remembering across sessions, that's the *caller's* job: chain into `knowledge-loop`
or `adr-write` afterward, this skill does not write memory itself.
