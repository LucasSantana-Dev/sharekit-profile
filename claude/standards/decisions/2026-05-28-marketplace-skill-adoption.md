# Marketplace skill adoption — alirezarezvani/claude-skills

- Date: 2026-05-28
- Status: Accepted
- Decision pipeline: `/research-and-decide` (marketplace inspection → dedup → critic → this ADR)

## Context

Evaluated the third-party plugin marketplace `alirezarezvani/claude-skills` (~150 skills across engineering / business / marketing / finance / c-level domains) for adoption into a mature, just-audited ~270-skill catalog. Inspected the dev-relevant domains (engineering, engineering-team) and deduped against the existing catalog + stack fit.

Findings: literal duplicates (caveman, grill-me, grill-with-docs, handoff, write-a-skill); poor-fit (helm/k8s/terraform/snowflake/aws/data/stats — bash-IaC homelab, k3s retired); overlap (docker-development, llm-cost-optimizer, slo-architect, security-guidance). Two finalists, **both full plugins** (bundle agents/ + hooks/ + .mcp.json + skills/):
- `self-improving-agent` — hooks `error-capture.sh` into memory; operator already has a PostToolUseFailure error-logging hook + sessionend-memory-writer + RAG + claude-mem + sync-memories.
- `playwright-pro` — 10 skills + BrowserStack/TestRail + own MCP; more comprehensive than `playwright-best-practices` + `webapp-testing`, but operator just disabled the `playwright` plugin (0 use) and has no Playwright e2e in any repo.

## Decision

**Install nothing now.**
- **REJECT** `self-improving-agent` — duplicate capability + third-party executable hooks on session events (supply-chain cost for marginal benefit).
- **REJECT** bulk-installing any domain plugin — bloat; directly undoes this session's removal of 65 dead symlinks from past bulk-installs.
- **DEFER** `playwright-pro` (skills-only lift, dropping hooks/.mcp.json/enterprise integrations) — genuinely good, but no current pull; option-value is not pull. Lifting later is a 5-minute local-only copy.
- Keep the marketplace as a **reference pointer only** (`standards/deferred-marketplaces.md`) — NOT added to active `extraKnownMarketplaces` / not auto-loaded scanning.

## Alternatives considered

- **Lift playwright-pro now on option-value** — rejected: violates pull-signal; "might need e2e someday" is exactly the speculative install the 65 dead symlinks represented.
- **Install self-improving-agent** — rejected: redundant with existing loop + third-party hook blast radius.
- **Bulk-install engineering domain** — rejected: 5-9 of 26 are dupes/poor-fit; re-adds scanning bloat.
- **Add to active known-marketplaces** — downgraded to reference-only: avoids a new always-scanning surface.

## Consequences

- (+) Zero new supply-chain surface; no catalog bloat; the just-cleaned baseline holds.
- (+) Explicit revisit trigger prevents a "forgotten deferral."
- (−) Latent-friction risk accepted: a genuinely useful tool (playwright-pro) is not pre-staged — mitigated by the trigger below.

## Revisit when

- **Operator commits the first Playwright e2e test to any repo** → re-evaluate lifting `playwright-pro`'s skills (skills-only, local-only). Ask: did the deferral cost >15 min of setup? If yes, relax pull-signal for comprehensive skill bundles; if no, the deferral was correct.
- 90-day check: if the marketplace got cherry-picked >2× ad hoc, audit whether those picks respected pull-signal.
