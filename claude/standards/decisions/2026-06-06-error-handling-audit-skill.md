# ADR: Keep `error-handling-audit` as a focused skill (override of "fold into code-review")

**Date:** 2026-06-06
**Status:** Accepted (operator override)

## Context

While regenerating the skills reference, `error-handling-audit` was found to be listed but
never actually implemented. The question: build it for real, or drop it? Run through
`/research-and-decide`.

- **Phase 1 (research):** established tools (SonarQube, Biome) bundle error-handling +
  resource-leaks under one "Reliability" domain. A tiered detection catalog was produced,
  ranked by static/LLM signal-to-noise (Tier 1 confident → Tier 3 runtime-only/noise).
- **Phase 2 (critic):** returned **DON'T-BUILD**. Verified true: `code-review` already owns
  this domain — its SKILL.md lists `resource safety (leaks)` as a first-class dimension with
  a `Leaks ✓` gate, and REFERENCE.md has a dedicated leaks section (handles, timers,
  listeners, pools, cleanup-on-error) plus Correctness (no swallowed errors, no floating
  promises). A second skill is redundant and risks noise on a framework-managed stack.

## Decision

**Build `error-handling-audit` anyway, as a deliberately narrowed, focused one-call lens** —
an operator override of the critic's fold-in recommendation. The operator wants a fast,
single-purpose unhappy-path pass (e.g. a risky module, remote-driving) distinct from a full
`/code-review`.

To make the override defensible rather than just additive, the skill is built **narrowed**:
- **Tier 1 high-signal patterns only** as confident findings; Tier 2 context-gated; Tier 3
  (pool starvation, stream backpressure, memory leaks, broad PII scan) excluded as runtime
  territory (pointed to `/observe`).
- **Framework-aware don't-flag list** — Prisma/Drizzle/`pg`/ioredis pooling, discord.js
  auto-cleanup, supervised `uncaughtException` (PM2/systemd/k8s), intentional `void`
  fire-and-forget, NODE_ENV-gated logging. These were the critic's noise landmines; they're
  now explicit non-findings.
- **Honest boundary**: the skill states up front that `/code-review` covers this and that the
  two should not double-run on the same diff — pick the depth you need.

## Alternatives considered

- **Don't build (critic's verdict)** — rejected by operator: wants a focused lens, not only
  the full review. The redundancy is accepted knowingly.
- **Fold into `/code-review` as reference entries** (add floating-promise / leak-on-error
  examples) — still worth doing independently, but doesn't give the standalone one-call lens.
- **Build broad ("reliability-audit" incl. memory leaks / pool starvation)** — rejected:
  those are runtime/profiling concerns; static findings there are noise.
- **Rename to `reliability-audit`** — rejected: operator's mental model + the reference PDF
  use `error-handling-audit`; renaming orphans both for marginal accuracy gain.

## Consequences

**Positive:** a fast, scope-tightenable, framework-aware unhappy-path lens for targeted
passes and remote-driving; the narrowing + don't-flag list keep signal-to-noise high.

**Negative:** real scope overlap with `/code-review` (the domain it already owns). Mitigated
by the explicit "when to use vs code-review" boundary and the don't-double-run rule — but the
overlap is the standing cost of this override.

**Neutral:** sits alongside `/overengineering-audit` as a second focused-lens sibling. Unlike
overengineering (which code-review covers only thinly as "code smells"), this one overlaps a
*thick* code-review dimension — that's the asymmetry that made it an override, not a clear add.

## Revisit when

- The skill produces false positives in practice (the don't-flag list proves insufficient) →
  fold into `/code-review` and delete it.
- Usage data shows it's rarely invoked / always followed by a full `/code-review` anyway →
  fold in; the focused lens isn't earning its slot.
- `/code-review` gains a fast focused-dimension mode (e.g. `--dimension leaks`) → this skill
  becomes redundant; retire it.
