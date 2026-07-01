# Harness Constitution

> Human-readable mirror of `.harness/constitution.json`. The JSON file is the source of truth; this document explains each section.

## Rank (enforcement order)

When rules conflict, higher-ranked sections override lower ones:

1. **Protected Invariants** — absolute constraints, never overridden
2. **Branch Policy** — git branching rules
3. **Verification Policy** — what must pass before each gate
4. **Escalate When** — conditions that require human decision
5. **Memory** — how knowledge is stored and retrieved
6. **Handoffs** — session continuity protocol

## Protected Invariants

These are non-negotiable. No task, no matter how urgent, may violate them.

| Invariant | Meaning |
|-----------|---------|
| `no-ai-attribution` | Never add AI co-author markers, "Generated with" trailers, or bot attribution to commits, PRs, issues, or release notes. Author of record is Lucas Santana. |
| `pr-automation-halt` | Never automate any action on a PR with comments from another person, or any open PR authored by another person. Bots (dependabot, renovate, coderabbit, sonar) do not count. |
| `independence-gate` | Review, security, and critic agents MUST be independent subagents — never collapsed into the implementer lane. |
| `read-only-by-construction` | Analysis agents (review, explore, plan, audit) must deny write/edit tools in their permission block — not just a prompt instruction. |
| `idempotency-check` | Before any write (file edit, API call, git push, DB upsert), query current state; if already satisfied, skip and log "already done." |
| `storage-policy` | New repos, clones, worktrees, datasets, model weights, and large caches go on `/Volumes/External HD/Desenvolvimento/`. Never clone or download large data under `~/` outside tool-config dirs. |
| `lean-catalog-preservation` | Do not restore archived wrapper skills just to recover wording; fold durable capability into active skills, standards, docs, or superseding memory first. |
| `self-mod-human-review` | No flywheel-originated change to hooks/, claude/skills/, claude/settings.json, .claude/settings.json, or .harness/ policy files may be applied to a live path or merged without explicit human (operator) approval. Terminal state for flywheel proposals is always "staged for human review", never "deployed". |
| `self-mod-rollback-contract` | Every proposal that reaches gate must carry an explicit rollback section: the exact revert action (file+baseline to restore or commit to revert) and the deploy-watch baseline metric to compare against. Gate rejects any proposal lacking a non-empty rollback section. |
| `self-mod-invariant-preservation` | Every proposal must declare which protected invariants its change touches. Gate rejects any proposal that removes, weakens, or bypasses a protected invariant. The protected-invariants list itself may only be changed by a human-authored PR, never by a flywheel proposal. |

## Branch Policy

| Branch | Protection Level |
|--------|-----------------|
| `main` | **Protected** — no direct push, PR required, CI must pass |
| `release/*` | **Protected** — no direct push, PR required, CI must pass |
| `feature/*` | **PR Required** — must go through PR to merge into main/release |

## Verification Policy

What must pass before each git gate:

| Gate | Required Checks |
|------|----------------|
| **Pre-commit** | `lint`, `type-check` |
| **Pre-push** | `test`, `build` |
| **Pre-merge** | `ci-pass`, `review-approved` |

## Escalate When

These conditions require stopping and asking the human before proceeding:

- **Security-sensitive** — changes touching auth, secrets, credentials, or infra permissions
- **Production-impacting** — changes that affect live systems or user-facing behavior
- **Irreversible** — destructive operations that cannot be undone (data deletion, force-push, schema drops)
- **Ambiguous intent** — when the task description could mean multiple things and the wrong choice is costly

## Memory

| Aspect | Value |
|--------|-------|
| Source of truth | Repository (committed ADRs, specs, decisions) |
| Per-project memory | `.agents/memory/` (gitignored, symlinked) |
| Global memory | `~/.claude/projects/<slug>/memory/` |
| Session state | `~/.claude/handoffs/<project>/latest.md` |

## Handoffs

| Aspect | Value |
|--------|-------|
| Trigger | Context approaching limit, session end, or explicit save |
| Location | `~/.claude/handoffs/<project>/latest.md` |
| Required fields | `task`, `current_step`, `completed`, `next_action`, `git_state` |
| Archive | On completion, move to `<timestamp>-completed.md` |
