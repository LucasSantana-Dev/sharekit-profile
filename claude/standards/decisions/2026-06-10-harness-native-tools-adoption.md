# Harness-native tools adoption — Workflow, Monitor, Routines, ultra, fast/effort

- Date: 2026-06-10
- Status: Accepted (with conditions)
- Decision pipeline: `/research-and-decide` (web sweep + local-setup audit → critic (Opus, REVISE) → reconcile → this ADR)

## Context

A Mar–Jun 2026 ecosystem sweep for the forgekit catalog surfaced that the biggest day-to-day misses are not third-party installs but harness-native Claude Code features the operator already has and doesn't use: Workflow tool, Monitor tool, /schedule Routines, /code-review ultra, /fast mode, Opus 4.8 effort levels. Account-gated candidates also surfaced: Claude Managed Agents (beta, $0.08/session-hr), Braintrust (evals), Brave Search MCP.

Critic review returned REVISE with three MAJOR findings: no cost ceiling, no revisit triggers, and "/schedule = de-facto Managed Agents adoption." Two critic claims were factually corrected on reconcile: (1) Workflow and Monitor run **local** subagents/streams — token cost only, no separate cloud billing; only Routines and ultra are cloud/billed. (2) Workflow does not replace composites — the composite contract still owns phases + reconciliation; Workflow is execution machinery *inside* a phase, so no reconciliation-format collision exists.

## Decision

**Adopt the harness-native bundle, with the critic's discipline conditions:**

1. **Workflow tool** — adopt with pilot gate: first use is one audit/backlog-style run; verify output lands cleanly in the invoking composite's reconciliation block before habitual use. Token-budget directives (`+500k`) bound each run.
2. **Monitor tool** — adopt for CI/log/deploy watching; replaces poll-sleep loops. Local, free.
3. **/schedule Routines** — adopt for NEW recurring tasks only (tasks not on launchd today AND needing off-Mac execution). Never migrate existing launchd jobs. Schedule off-hours (22:00–06:00 BRT) to avoid RAG-index/parallel-agent contention. Acknowledged: this IS an incremental commitment to Managed-Agents-category infrastructure.
4. **/code-review ultra** — high-stakes diffs to main/release only; note in memory which PRs used it.
5. **/fast + effort levels** — /fast ($10/$50 MTok) when wall-clock matters on Opus-quality work; it is a speed premium, not a tier — Haiku still owns mechanical work. `xhigh` effort for architecture/ADR chains only.

**Keep Sunday diagnostics on local launchd** — stable, free, offline-first; no change.

**Cloud cost ceiling: $25/month** across Routines + ultra. Quarterly spot-check via token-audit / billing.

## Alternatives considered

- **Claude Managed Agents now** — deferred: beta, new infra, no current off-Mac pull; Routines cover the near-term need.
- **Braintrust** — deferred: eval work is not weekly; langfuse covers observability.
- **Brave Search MCP** — rejected: redundant with built-in WebSearch + firecrawl.
- **Migrate launchd → Routines** — rejected: working system, zero cost, no cross-machine need; migration adds billing + a second scheduler to reason about.
- **Defer everything (skeptic position)** — rejected: Workflow/Monitor/fast are zero-install, zero-lock-in, trivially reversible; "stop using" is the rollback.

## Consequences

- (+) Deterministic orchestration and live monitoring with no new supply-chain surface.
- (+) Standards now encode the preference (`standards/workflow.md` § Harness-native tools), so all future sessions inherit it.
- (−) Accepted: small ongoing billed spend for ultra/Routines, capped at $25/month.
- (−) Accepted: /schedule usage is a soft entry into Managed-Agents-category dependence; bounded by the "NEW tasks only" rule.
- (n) Composites unchanged; Workflow slots inside composite phases.

## Revisit when

- **Cloud spend (Routines + ultra) > $25/month** → evaluate Managed Agents consolidation vs cutting usage.
- **≥3 recurring tasks need off-Mac execution** → trial Managed Agents properly.
- **Eval work becomes ≥weekly** → adopt Braintrust.
- **Built-in WebSearch blocks research ≥2× in a month** → re-evaluate Brave Search MCP.
- **Workflow pilot output breaks a composite's reconciliation parsing** → amend composite-contract.md before further Workflow use.
- **90-day check (2026-09-10)**: if Workflow/Monitor were used <3× total, the adoption was aspirational — remove the standards section rather than carry dead guidance.
