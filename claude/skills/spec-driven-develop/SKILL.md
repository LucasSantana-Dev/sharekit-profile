---
name: spec-driven-develop
description: "Default composite for non-trivial build/add/fix/implement/refactor work. Drives work through spec-driven-development phases: constitution - specify - clarify - plan - tasks - implement - verify. Adapts GitHub spec-kit workflow onto existing harness skills. No new dependency, maintains docs/specs convention. Supersedes /plan as default for multi-step work."
tags:
- composite
- planning
- implementation
- spec-driven
platforms:
- Claude
metadata:
  owner: global-agents
  tier: orchestration
  canonical_source: ~/.claude/skills/spec-driven-develop
triggers:
  - build a non-trivial feature
  - add a feature
  - fix a bug
  - implement this
  - refactor a multi-file module
  - multi-step work
---

# Spec-Driven Develop

Composite skill. Chains existing skills into spec-kit's phase order and terminology, without spec-kit's CLI or `.specify/` directory convention.

## Why this exists

GitHub's spec-kit enforces a structured spec - plan - tasks - implement workflow via a `specify` CLI that scaffolds `.specify/` templates. This harness already has an equivalent skill for every phase: `adt-specs-spec-new`, `grill-with-docs`, `plan`, `plan-to-issues`, `dispatch`/`orchestrate`, `review`/`verify`. Installing the actual CLI would duplicate that coverage, add an external dependency, and fight the existing `docs/specs/<date>-<slug>/` convention. This skill gets spec-kit's discipline (explicit phases, no skipping straight to code) without the tool.

## Phase mapping

| Spec-kit phase | This skill's step | Sub-skill invoked |
|---|---|---|
| constitution | Phase 0 - confirm CLAUDE.md/CONTEXT.md exist for the repo; if `.harness/constitution.json` exists, treat it as authoritative (not `constitution.md`, its human-readable mirror) and also read `.harness/mcp-policy.json` when present; note gaps, don't block | (read-only check) |
| specify | Phase 1 - create/find the spec | `adt-specs-spec-new` - `docs/specs/<date>-<slug>/spec.md` |
| clarify | Phase 2 - resolve ambiguity inline | `grill-with-docs` |
| plan | Phase 3 - phased implementation plan | `plan` - `.claude/plans/<name>.md` (or `.agents/plans/`) - that skill's real output location; the persisted spec from Phase 1 is what carries forward past session scope, not this plan file |
| tasks | Phase 4 - externalize tasks if tracked work | `plan-to-issues` (skip if session-scoped, not tracked) |
| implement | Phase 5 - execute tasks, parallel where independent | `dispatch` / `orchestrate` / `loop` (mandatory parallel-execution rule applies) |
| analyze / converge | Phase 6 - gate before done | `review`, `verify`, `pr-merge-readiness` |

## Stop conditions

- **Trivial edit** (<3 files, mechanical, no ambiguity): skip this pipeline entirely, go straight to `add` or a direct edit. Forcing the full phase sequence on a one-line fix is the exact overhead the "negative rules" in `skill-auto-invoke.md` warn against.
- **Read-only ask** (audit, analysis, question): this skill doesn't apply. Use the diagnostic skill directly.
- **A more specific composite matches** (hotfix, incident-response, release-cut, merge-confidently, debug-deep, or any other named lifecycle composite): defer to it. This skill is the default for build/add/fix/implement when nothing more specific matches, not a universal override.
- **Bailing mid-phase**: surface the blocker as this skill's output, mark the phase incomplete, resume next turn. Never silently drop to ad-hoc editing (same contract as other composites, `standards/composite-contract.md`).

## Interop with actual spec-kit projects

If a repo already has a `.specify/` directory (from someone using the real spec-kit CLI), read its templates as seed input for Phase 1. But write output under `docs/specs/<date>-<slug>/`, not `.specify/`. Never install the `specify` CLI as part of this skill; that decision needs an explicit ask (new external dependency).

## Done when

- Phase 0: Constitution check complete, any CLAUDE.md/CONTEXT.md gaps documented.
- Phase 1: Spec file created or updated under `docs/specs/<date>-<slug>/spec.md`.
- Phase 2: Ambiguities resolved, spec validated against actual requirements.
- Phase 3: Phased implementation plan written to `.claude/plans/<name>.md` (or `.agents/plans/`).
- Phase 4: GitHub issues created (if tracked work) or phase skipped for session-scoped work.
- Phase 5: All tasks executed in parallel where independent, changes staged and ready.
- Phase 6: Code review passed, verification gates satisfied, ready to merge or ship.
