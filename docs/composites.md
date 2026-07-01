# Composites: Chained Skills & Gatekeeping

Composite behavior now lives mostly inside active skills rather than many standalone wrapper commands. Prefer the active entry point that owns the workflow; archived wrappers remain recoverable in `claude/skills/.archive/` but should not be documented as active slash commands.

---

## Composite-first rule

When routing suggests a composite workflow, invoke the active composite or skill sequence. Do not manually skip phases such as scope, validation, review, or memory capture.

---

## Active composite/workflow entry points

### /session-bootstrap

Start-of-session context rehydration and next-action selection.

**Flow:** resume context → next-priority → context-pack.

### /knowledge-loop

Knowledge preservation and session closeout.

**Flow:** recall → capture → curate weak retrievals → handoff.

### /rag-maintenance

RAG health and drift repair.

**Flow:** quality report → coverage audit → drift detection → curation/reindex/rebuild decision.

### /quality-assurance

QA strategy composer for releases, risky changes, and maintenance sweeps.

**Flow:** classify goal → choose gates → order cheap-to-expensive checks → consolidate evidence.

### /quality-gates

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

### /ads

Paid-advertising audit/management specialist (Google, Meta, LinkedIn, TikTok) — read/analyze/report only, no live-account mutation.

**Flow:** business-context preflight → mode dispatch (`audit`/platform deep-dive/`creative`/`budget`/`competitor`/`plan`/`report`) → scored findings with cited evidence → optional `knowledge-loop` chain if a durable rule emerges.

---

## Replacements for archived wrappers

| Archived wrapper | Active equivalent |
|---|---|
| `session-wrap-up` | `knowledge-loop` plus `ship` when release work happened |
| `refactor-pipeline` | `request-refactor-plan` → `orchestrate`/`three-man-team` → `quality-gates` → `knowledge-loop` |
| `verify-before-done` | `quality-gates` plus `verify` for final confidence |
| `debug-deep` / `systematic-debugging` | `debug` with CI/Sentry/trace evidence when relevant |
| `security-sweep`, `security-audit`, `security-scan`, `semgrep` | `secure` plus scanner evidence under `quality-gates` |
| `onboard-new-repo` | `session-bootstrap` → `context-pack` → `quality-assurance` |
| `feature-from-zero` | `scope-it` → `plan` → design/TDD skills → `quality-gates` → `ship` |
| `rag-quality`, `rag-curate`, `adt-rag-coverage`, `adt-rag-drift` | `rag-maintenance` |
| `route` | `scope-it` or `fallback`, depending on whether the problem is ambiguous or blocked |
| `smart-model-select` | model-tier policy in `AGENTS.md` |

---

## Bail-out rule

If a composite cannot complete a phase, output the blocker and mark that phase incomplete. Do not silently switch to a sub-skill or pretend the gate passed.

**Last updated:** 2026-07-01
