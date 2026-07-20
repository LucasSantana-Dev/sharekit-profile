# Decision: canonical skills reconciliation post-4739300

- **Date:** 2026-06-10
- **Status:** Accepted
- **Process:** /research-and-decide (evidence trail + critic review, session 2026-06-10)
- **Governs:** the 250-file uncommitted delta in claude-env `skills/` and the partial reversal of commit 4739300.

## Context

Commit 65f46c2 (2026-05-13, indiscriminate auto-sync) bulk-committed ~106 skill
directories into canonical that were never tracked in skills.git (ai-elements,
chat-sdk, ai-gateway, build-mcp-*, auth, bootstrap, github, workflow, …). The
2026-05-28 topology standard was created in response: canonical promotion requires
per-skill review, never bulk reconciliation. Consolidation waves in skills.git
(b5a8f0c, 8dd1f20) removed those skills from the live catalog; the deletions
back-synced into canonical's working tree, surfacing today.

Separately, commit 4739300 (2026-06-10, audit-remediation agent) bulk-promoted 29
local-only skills into canonical — a good-faith violation of the same standard
(the executing agent treated local-only as drift; the standard says it is the
governed default).

## Decision

1. **Commit the 172 deletions** — they remove pre-governance pollution from
   65f46c2 and align canonical to the curated post-consolidation state.
2. **Of the 29 bulk-promoted skills, keep 20 + rtk-health, demote 8.**
   - *Review signal amendment:* a skill tracked in skills.git (the curated
     working repo) has passed working-repo review; its canonical promotion is
     ratified retroactively. This covers 20 of the 29.
   - *rtk-health* received explicit per-skill review today (rebuilt, tested,
     documented) — kept.
   - *Demoted (8, canonical-only AND superseded in live by today's
     consolidation):* trigger-agents, trigger-config, trigger-realtime,
     trigger-setup, trigger-tasks (superseded by trigger-dev), context-manager,
     security-best-practices, shadcn-ui (superseded by shadcn /
     security-audit / optimize-context coverage). Removed from canonical;
     on-disk copies are unaffected (sync pull has no --delete).
   - *using-git-worktrees* (canonical-only but alive in the catalog): kept,
     ratified by this record as its per-skill review.
3. **Commit the 65 modifications + substantive untracked files** (decision
   records, trigger-dev, references, .gitignore; exclude __pycache__) — these
   are reviewed skills.git work back-synced to canonical.
4. **Exclude `skills/shorts-edit/` from all commits** — a concurrent session
   has uncommitted work in flight there; its own mirror flow owns that path.

## Consequences

- Canonical returns to curated state; the never-bulk-reconcile rule stands.
- Agent-driven audits must read skill-catalog-topology.md before "fixing"
  skill drift — added to the revisit list for the audit skill prompts.

## Revisit when

- trigger-dev proves insufficient and any trigger-* skill is needed back
  (restore from git: `git checkout 4739300 -- skills/trigger-<name>`).
- The topology standard itself changes.
