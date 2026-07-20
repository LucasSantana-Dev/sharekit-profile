# Skill catalog topology & promotion governance

- Date: 2026-05-28
- Status: Accepted
- Decision pipeline: `/research-and-decide` (3 research agents → critic → this ADR)

## Context

A skill audit (workflow `w27xmrkj5`) plus a reconciliation investigation appeared to show chaos in `~/.claude/skills`: 176/243 skills "untracked", the repo "3 weeks stale", 10 skills "deleted-uncommitted". Investigation showed the alarm was about the **wrong repo**:

- `~/.claude/skills` is a **symlink** to `~/.agents/skills` (`skills.git`) — a downstream working copy / curated 83-skill export.
- The **canonical** source `~/.claude-env/` (`claude-env.git`) is healthy: 223 skills tracked, working tree clean, synced ~5h before investigation.
- True gap: only **25** on-disk skills are absent from canonical (not 176). No data loss — `recall`/`ship`/`ui-expert`/`knowledge-loop`/`refactor` etc. are all tracked in canonical.

A prior "big reconcile" proposal (one commit capturing every untracked skill into `~/.claude/skills`) was rejected: it targeted the downstream subset-repo, would have corrupted the curated export, and solved a non-problem.

## Decision

1. **The 3-tier topology is intentional** (canonical / working-copy / export) — see `standards/skill-catalog-topology.md`.
2. **Skills are local-only by default.** Promotion to canonical `claude-env` requires per-skill review + classification, never bulk reconciliation.
3. **No promotion/dead-ref automation** (hook/launchd) — deferred on pull-signal grounds (cost is incident-driven, not session-authored; ADR-0005 precedent).
4. **First-pass classification of the 25 local-only skills** (from audit verdicts):
   - **Canonical-ready (promote, 12):** brief-and-drill, decide, drift-detect, env-completeness, gh-actions-author, incident-lifecycle, naming-consistency, prisma-migrate, test-backend, test-mutation, test-sweep, adr-gap — *`adr-gap` reclassified KEEP→promote: it feeds `decide` via an auto-invoke trigger, so it follows `decide` into canonical. The audit's KILL ("no post-hoc audits") was a misjudgment given the operator's heavy ADR discipline.*
   - **Local-only / experimental (hold, 12):** acceptance-criteria, coupling-map, error-handling-audit, feature-inventory, orphan-hunt, scope-it, seo-a11y-audit, test-isolation-check, test-plan, test-webapp, trunk-based-dev, uiforge-deploy-staging
   - **Remove (1, out-of-stack):** api-consistency (zero refs; no REST/GraphQL API-design work in stack)

## Alternatives considered

- **Bulk-commit all 25 into canonical** — rejected (category error: unvetted code into the source of truth).
- **Big reconcile into `~/.claude/skills`** — rejected (wrong repo; corrupts curated export; canonical is healthy).
- **Automation hook for promotion + post-deletion dead-ref grep** — rejected (pull-signal fail; ADR-0005 precedent).
- **Alternative VC models** (chezmoi / GNU stow / yadm / git submodule) — researched, out of scope; canonical + `sync pull` already works and is clean. No tool migration without documented pull.

## Consequences

- (+) Canonical stays clean; promotion is deliberate, not a periodic panic.
- (+) Dead-symlink + audit hygiene becomes a known on-demand sweep, not an emergency.
- (−) 12 local-only skills stay unreviewed until individually triaged.
- (~) `skills.git` export staleness is a separate, low-priority question.

## Revisit when

- An incident where a local-only skill being absent from canonical costs time (e.g. canonical references a local-only skill).
- ≥3 sessions document promotion-cadence friction → re-evaluate the automation option.
- The `skills.git` export's purpose/consumption is clarified.
