# Composites: Chained Skills & Gatekeeping

Composite behavior now lives mostly inside active skills rather than many standalone wrapper commands. Prefer the active entry point that owns the workflow; archived wrappers remain recoverable in `claude/skills/.archive/` but should not be documented as active slash commands.


| `ponytail` | archived — zero-use per canonical 30d audit (2026-07-01) |
| `quality-gates` | archived — zero-use per canonical 30d audit; use `verify` + `test-health` + `security-audit` (2026-07-01) |
| `quality-assurance` | archived — zero-use per canonical 30d audit; use `test-health` + `security-audit` (2026-07-01) |
| `rag-maintenance` | archived — consolidated into `rag-curate` + `adt-rag-drift` (2026-07-01) |
| `scope-it` | archived — superseded by `scope-and-execute` (2026-07-01) |
| `architecture-patterns` | archived — zero-use per canonical 30d audit; use `improve-codebase-architecture` (2026-07-01) |
| `codebase-design` | archived — zero-use per canonical 30d audit; see `impeccable` for design review (2026-07-01) |
| `context-save` | archived — zero-use per canonical 30d audit; use `sync-memories` or `handoff` (2026-07-01) |
| `domain-modeling` | archived — zero-use per canonical 30d audit (2026-07-01) |
| `request-refactor-plan` | archived — zero-use per canonical 30d audit; use `refactor-pipeline` directly (2026-07-01) |
| `setup-pre-commit` | archived — zero-use per canonical 30d audit; pre-commit setup in `onboard-new-repo` or `session-bootstrap` (2026-07-01) |
| `skill-creator-plugin` | archived — plugin-injected at runtime, never a repo skill; removed from showcase page (2026-07-01) |
---

## Composite-first rule

When routing suggests a composite workflow, invoke the active composite or skill sequence. Do not manually skip phases such as scope, validation, review, or memory capture.


| `ponytail` | archived — zero-use per canonical 30d audit (2026-07-01) |
| `quality-gates` | archived — zero-use per canonical 30d audit; use `verify` + `test-health` + `security-audit` (2026-07-01) |
| `quality-assurance` | archived — zero-use per canonical 30d audit; use `test-health` + `security-audit` (2026-07-01) |
| `rag-maintenance` | archived — consolidated into `rag-curate` + `adt-rag-drift` (2026-07-01) |
| `scope-it` | archived — superseded by `scope-and-execute` (2026-07-01) |
| `architecture-patterns` | archived — zero-use per canonical 30d audit; use `improve-codebase-architecture` (2026-07-01) |
| `codebase-design` | archived — zero-use per canonical 30d audit; see `impeccable` for design review (2026-07-01) |
| `context-save` | archived — zero-use per canonical 30d audit; use `sync-memories` or `handoff` (2026-07-01) |
| `domain-modeling` | archived — zero-use per canonical 30d audit (2026-07-01) |
| `request-refactor-plan` | archived — zero-use per canonical 30d audit; use `refactor-pipeline` directly (2026-07-01) |
| `setup-pre-commit` | archived — zero-use per canonical 30d audit; pre-commit setup in `onboard-new-repo` or `session-bootstrap` (2026-07-01) |
| `skill-creator-plugin` | archived — plugin-injected at runtime, never a repo skill; removed from showcase page (2026-07-01) |
---

## Active composite/workflow entry points

### /session-bootstrap

Start-of-session context rehydration and next-action selection.

**Flow:** resume context → next-priority → context-pack.

### /knowledge-loop

Knowledge preservation and session closeout.

**Flow:** recall → capture → curate weak retrievals → handoff.

RAG health and drift repair.

**Flow:** quality report → coverage audit → drift detection → curation/reindex/rebuild decision.

QA strategy composer for releases, risky changes, and maintenance sweeps.

**Flow:** classify goal → choose gates → order cheap-to-expensive checks → consolidate evidence.

Binary repository-native verification.

**Flow:** format/lint/type → tests → build → security/docs → CI contract snapshot.

### /dispatch

Parallel investigation fan-out.

**Flow:** decompose independent tracks → launch workers → reconcile findings.

### /orchestrate

Multi-agent/multi-repo coordination.

**Flow:** plan ownership → isolate worktrees/branches → run lanes → integrate → validate.

### /three-man-team

High-complexity lane separation.

**Flow:** architect strategy → builder implementation → reviewer critique → integration.

### /request-refactor-plan

Safe broad-refactor setup.

**Flow:** discovery → scope/rollback → validation plan → handoff to `orchestrate` or `three-man-team`.

## Replacements for archived wrappers

| Archived wrapper | Active equivalent |
|---|---|
| `session-wrap-up` | `knowledge-loop` plus `ship` when release work happened |
| `refactor-pipeline` | Use `/refactor` for surgical refactoring; use `/plan` + `/orchestrate` for scope/rollback phases |
| `verify-before-done` | `/verify` for validation gates; pair with specific test/security checks via `/secure` |
| `debug-deep` / `systematic-debugging` | `debug` with CI/Sentry/trace evidence when relevant |
| `security-sweep`, `security-audit`, `security-scan`, `semgrep` | Use `/secure` for security-first assessment and pattern scanning |
| `onboard-new-repo` | `/session-bootstrap` → `/context-pack` → `/verify` + `/secure` |
| `feature-from-zero` | `/plan` → design/TDD skills → `/verify` → `/ship` |
| `rag-quality`, `rag-curate`, `adt-rag-coverage`, `adt-rag-drift` | Now `rag-curate` + `adt-rag-drift` (internal chain via `knowledge-loop`) |
| `route` | `/plan` or `/fallback`, depending on whether the problem is ambiguous or blocked |
| `smart-model-select` | model-tier policy in `AGENTS.md` |
| `ads` | moved to its client project (private) — client-scoped skills don't ship in the public catalog |
| `ponytail` | archived — zero-use per canonical 30d audit (2026-07-01) |
| `quality-gates` | archived — zero-use per canonical 30d audit; use `verify` + `test-health` + `security-audit` (2026-07-01) |
| `quality-assurance` | archived — zero-use per canonical 30d audit; use `test-health` + `security-audit` (2026-07-01) |
| `rag-maintenance` | archived — consolidated into `rag-curate` + `adt-rag-drift` (2026-07-01) |
| `scope-it` | archived — superseded by `scope-and-execute` (2026-07-01) |
| `architecture-patterns` | archived — zero-use per canonical 30d audit; use `improve-codebase-architecture` (2026-07-01) |
| `codebase-design` | archived — zero-use per canonical 30d audit; see `impeccable` for design review (2026-07-01) |
| `context-save` | archived — zero-use per canonical 30d audit; use `sync-memories` or `handoff` (2026-07-01) |
| `domain-modeling` | archived — zero-use per canonical 30d audit (2026-07-01) |
| `request-refactor-plan` | archived — zero-use per canonical 30d audit; use `refactor-pipeline` directly (2026-07-01) |
| `setup-pre-commit` | archived — zero-use per canonical 30d audit; pre-commit setup in `onboard-new-repo` or `session-bootstrap` (2026-07-01) |
| `skill-creator-plugin` | archived — plugin-injected at runtime, never a repo skill; removed from showcase page (2026-07-01) |
---

## Bail-out rule

If a composite cannot complete a phase, output the blocker and mark that phase incomplete. Do not silently switch to a sub-skill or pretend the gate passed.

**Last updated:** 2026-07-01
